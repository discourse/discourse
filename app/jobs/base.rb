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
    Sidekiq::RetrySet.new.select { |job| job.klass =~ /Email$/ }.size
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
      puts args
      args.each do |arg|
        Rails.logger.info "#{Time.now.to_formatted_s(:db)}: [#{self.class.name.upcase}] #{arg}"
      end
      true
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
          return execute(opts)
        end
      end


      dbs =
        if opts[:current_site_id]
          [opts[:current_site_id]]
        else
          RailsMultisite::ConnectionManagement.all_dbs
        end

      total_db_time = 0
      dbs.each do |db|
        begin
          thread_exception = nil
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
              execute(opts)
            rescue => e
              thread_exception = e
            ensure
              ActiveRecord::Base.connection_handler.clear_active_connections!
              total_db_time += Instrumenter.stats.duration_ms
            end
          end
          t.join

          raise thread_exception if thread_exception
        end
      end

    ensure
      ActiveRecord::Base.connection_handler.clear_active_connections!
      @db_duration = total_db_time
    end

  end

  class Scheduled < Base
    include Sidetiq::Schedulable
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
        klass.delay_for(opts.delete(:delay_for)).delayed_perform(opts)
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
    enqueue_in( [(datetime - Time.zone.now).to_i, 0].max, job_name, opts )
  end

  def self.cancel_scheduled_job(job_name, params={})
    jobs = scheduled_for(job_name, params)
    return false if jobs.empty?
    jobs.each { |job| job.delete }
    true
  end

  def self.scheduled_for(job_name, params={})
    job_class = "Jobs::#{job_name.to_s.camelcase}"
    Sidekiq::ScheduledSet.new.select do |scheduled_job|
      if scheduled_job.klass == 'Sidekiq::Extensions::DelayedClass'
        job_args = YAML.load(scheduled_job.args[0])
        job_args_class, _, (job_args_params, *) = job_args
        if job_args_class.to_s == job_class && job_args_params
          matched = true
          params.each do |key, value|
            unless job_args_params[key] == value
              matched = false
              break
            end
          end
          matched
        else
          false
        end
      else
        false
      end
    end
  end
end

# Require all jobs
Dir["#{Rails.root}/app/jobs/regular/*.rb"].each {|file| require_dependency file }
Dir["#{Rails.root}/app/jobs/scheduled/*.rb"].each {|file| require_dependency file }
