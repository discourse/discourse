require 'scheduler/scheduler'

module Jobs

  def self.queued
    Sidekiq::Stats.new.enqueued
  end

  def self.last_job_performed_at
    Sidekiq.redis do |r|
      int = r.get('last_job_perform_at')
      int ? Time.at(int.to_i) : nil
    end
  end

  def self.num_email_retry_jobs
    Sidekiq::RetrySet.new.count { |job| job.klass =~ /Email$/ }
  end

  class Base

    class Instrumenter

      def self.stats
        Thread.current[:db_stats] ||= Stats.new
      end

      class Stats
        attr_accessor :query_count, :duration_ms

        def initialize
          @query_count = 0
          @duration_ms = 0
        end
      end

      def call(name, start, finish, message_id, values)
        stats = Instrumenter.stats
        stats.query_count += 1
        stats.duration_ms += (((finish - start).to_f) * 1000).to_i
      end
    end

    include Sidekiq::Worker

    def initialize
      @db_duration = 0
    end

    def log(*args)
      args.each do |arg|
        Rails.logger.info "#{Time.now.to_formatted_s(:db)}: [#{self.class.name.upcase}] #{arg}"
      end
      true
    end

    # Construct an error context object for Discourse.handle_exception
    # Subclasses are encouraged to use this!
    #
    # `opts` is the arguments passed to execute().
    # `code_desc` is a short string describing what the code was doing (optional).
    # `extra` is for any other context you logged.
    # Note that, when building your `extra`, that :opts, :job, and :code are used by this method,
    # and :current_db and :current_hostname are used by handle_exception.
    def error_context(opts, code_desc = nil, extra = {})
      ctx = {}
      ctx[:opts] = opts
      ctx[:job] = self.class
      ctx[:message] = code_desc if code_desc
      ctx.merge!(extra) if extra != nil
      ctx
    end

    def self.delayed_perform(opts={})
      self.new.perform(opts)
    end

    def execute(opts={})
      raise "Overwrite me!"
    end

    def last_db_duration
      @db_duration || 0
    end

    def ensure_db_instrumented
      @@instrumented ||= begin
        ActiveSupport::Notifications.subscribe('sql.active_record', Instrumenter.new)
        true
      end
    end

    def perform(*args)
      total_db_time = 0
      ensure_db_instrumented
      opts = args.extract_options!.with_indifferent_access

      if SiteSetting.queue_jobs?
        Sidekiq.redis do |r|
          r.set('last_job_perform_at', Time.now.to_i)
        end
      end

      if opts.delete(:sync_exec)
        if opts.has_key?(:current_site_id) && opts[:current_site_id] != RailsMultisite::ConnectionManagement.current_db
          raise ArgumentError.new("You can't connect to another database when executing a job synchronously.")
        else
          begin
            retval = execute(opts)
          rescue => exc
            Discourse.handle_job_exception(exc, error_context(opts))
          end
          return retval
        end
      end


      dbs =
        if opts[:current_site_id]
          [opts[:current_site_id]]
        else
          RailsMultisite::ConnectionManagement.all_dbs
        end

      exceptions = []
      dbs.each do |db|
        begin
          thread_exception = {}
          # NOTE: This looks odd, in fact it looks crazy but there is a reason
          #  A bug in therubyracer means that under certain conditions running in a fiber
          #  can cause the whole v8 context to corrupt so much that it will hang sidekiq
          #
          #  If you are brave and want to try to fix this either in celluloid or therubyracer, the repro is:
          #
          #  1. Create a big Discourse db: (you can start from script/profile_db_generator.rb)
          #  2. Queue a ton of jobs, eg: User.pluck(:id).each{|id| Jobs.enqueue(:user_email, type: :digest, user_id: id)};
          #  3. Run sidekiq
          #
          #  The issue only happens in Ruby 2.0 for some reason, you start getting V8::Error with no context
          #
          #  See: https://github.com/cowboyd/therubyracer/issues/206
          #
          #  The restricted stack space of fibers opens a bunch of risks up, by avoiding them altogether
          #   we can mitigate giving up a very marginal amount of throughput
          #
          #  Ideally we could just tell sidekiq to avoid fibers

          t = Thread.new do
            begin
              RailsMultisite::ConnectionManagement.establish_connection(db: db)
              I18n.locale = SiteSetting.default_locale
              I18n.ensure_all_loaded!
              begin
                execute(opts)
              rescue => e
                thread_exception[:ex] = e
                thread_exception[:other] = { problem_db: db }
              end
            rescue => e
              thread_exception[:ex] = e
              thread_exception[:message] = "While establishing database connection to #{db}"
              thread_exception[:other] = { problem_db: db }
            ensure
              ActiveRecord::Base.connection_handler.clear_active_connections!
              total_db_time += Instrumenter.stats.duration_ms
            end
          end
          t.join

          exceptions << thread_exception unless thread_exception.empty?
        end
      end

      if exceptions.length > 0
        exceptions.each do |exception_hash|
          Discourse.handle_job_exception(exception_hash[:ex], error_context(opts, exception_hash[:code], exception_hash[:other]))
        end
        raise HandledExceptionWrapper.new(exceptions[0][:ex])
      end

      nil
    ensure
      ActiveRecord::Base.connection_handler.clear_active_connections!
      @db_duration = total_db_time
    end

  end

  class HandledExceptionWrapper < StandardError
    attr_accessor :wrapped
    def initialize(ex)
      super("Wrapped #{ex.class}: #{ex.message}")
      @wrapped = ex
    end
  end

  class Scheduled < Base
    extend Scheduler::Schedule

    def perform(*args)
      return if Discourse.readonly_mode?
      super
    end
  end

  def self.enqueue(job_name, opts={})
    klass = "Jobs::#{job_name.to_s.camelcase}".constantize

    # Unless we want to work on all sites
    unless opts.delete(:all_sites)
      opts[:current_site_id] ||= RailsMultisite::ConnectionManagement.current_db
    end

    # If we are able to queue a job, do it
    if SiteSetting.queue_jobs?
      if opts[:delay_for].present?
        klass.perform_in(opts.delete(:delay_for), opts)
      else
        Sidekiq::Client.enqueue(klass, opts)
      end
    else
      # Otherwise execute the job right away
      opts.delete(:delay_for)
      opts[:sync_exec] = true
      klass.new.perform(opts)
    end

  end

  def self.enqueue_in(secs, job_name, opts={})
    enqueue(job_name, opts.merge!(delay_for: secs))
  end

  def self.enqueue_at(datetime, job_name, opts={})
    secs = [(datetime - Time.zone.now).to_i, 0].max
    enqueue_in(secs, job_name, opts)
  end

  def self.cancel_scheduled_job(job_name, params={})
    scheduled_for(job_name, params).each(&:delete)
  end

  def self.scheduled_for(job_name, params={})
    params = params.with_indifferent_access
    job_class = "Jobs::#{job_name.to_s.camelcase}"
    Sidekiq::ScheduledSet.new.select do |scheduled_job|
      if scheduled_job.klass.to_s == job_class
        matched = true
        job_params = scheduled_job.item["args"][0].with_indifferent_access
        params.each do |key, value|
          if job_params[key] != value
            matched = false
            break
          end
        end
        matched
      else
        false
      end
    end
  end
end

Dir["#{Rails.root}/app/jobs/onceoff/*.rb"].each {|file| require_dependency file }
Dir["#{Rails.root}/app/jobs/regular/*.rb"].each {|file| require_dependency file }
Dir["#{Rails.root}/app/jobs/scheduled/*.rb"].each {|file| require_dependency file }
