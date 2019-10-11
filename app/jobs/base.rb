# frozen_string_literal: true

module Jobs

  def self.queued
    Sidekiq::Stats.new.enqueued
  end

  def self.run_later?
    !@run_immediately
  end

  def self.run_immediately?
    !!@run_immediately
  end

  def self.run_immediately!
    @run_immediately = true
  end

  def self.run_later!
    @run_immediately = false
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
    class JobInstrumenter
      def initialize(job_class:, opts:, db:, jid:)
        return unless enabled?
        self.class.mutex.synchronize do
          @data = {}

          @data["hostname"] = `hostname`.strip # Hostname
          @data["pid"] = Process.pid # Pid
          @data["database"] = db # DB name - multisite db name it ran on
          @data["job_id"] = jid # Job unique ID
          @data["job_name"] = job_class.name # Job Name - eg: Jobs::AboutStats
          @data["job_type"] = job_class.try(:scheduled?) ? "scheduled" : "regular" # Job Type - either s for scheduled or r for regular
          @data["opts"] = opts.to_json # Params - json encoded params for the job

          if ENV["DISCOURSE_LOG_SIDEKIQ_INTERVAL"]
            @data["status"] = "starting"
            write_to_log
          end

          @data["status"] = "pending"
          @start_timestamp = Process.clock_gettime(Process::CLOCK_MONOTONIC)

          self.class.ensure_interval_logging!
          @@active_jobs ||= []
          @@active_jobs << self

          MethodProfiler.ensure_discourse_instrumentation!
          MethodProfiler.start
        end
      end

      def stop(exception:)
        return unless enabled?
        self.class.mutex.synchronize do
          profile = MethodProfiler.stop

          @@active_jobs.delete(self)

          @data["duration"] = profile[:total_duration] # Duration - length in seconds it took to run
          @data["sql_duration"] = profile.dig(:sql, :duration) || 0 # Sql Duration (s)
          @data["sql_calls"] = profile.dig(:sql, :calls) || 0 # Sql Statements - how many statements ran
          @data["redis_duration"] = profile.dig(:redis, :duration) || 0 # Redis Duration (s)
          @data["redis_calls"] = profile.dig(:redis, :calls) || 0 # Redis commands
          @data["net_duration"] = profile.dig(:net, :duration) || 0 # Redis Duration (s)
          @data["net_calls"] = profile.dig(:net, :calls) || 0 # Redis commands

          if exception.present?
            @data["exception"] = exception # Exception - if job fails a json encoded exception
            @data["status"] = 'failed'
          else
            @data["status"] = 'success' # Status - fail, success, pending
          end

          write_to_log
        end
      end

      def self.raw_log(message)
        @@logger ||= begin
          f = File.open "#{Rails.root}/log/sidekiq.log", "a"
          f.sync = true
          Logger.new f
        end
        @@log_queue ||= Queue.new
        @@log_thread ||= Thread.new do
          begin
            loop { @@logger << @@log_queue.pop }
          rescue Exception => e
            Discourse.warn_exception(e, message: "Sidekiq logging thread terminated unexpectedly")
          end
        end
        @@log_queue.push(message)
      end

      def current_duration
        Process.clock_gettime(Process::CLOCK_MONOTONIC) - @start_timestamp
      end

      def write_to_log
        return unless enabled?
        @data["@timestamp"] = Time.now
        @data["duration"] = current_duration if @data["status"] == "pending"
        self.class.raw_log("#{@data.to_json}\n")
      end

      def enabled?
        ENV["DISCOURSE_LOG_SIDEKIQ"] == "1"
      end

      def self.mutex
        @@mutex ||= Mutex.new
      end

      def self.ensure_interval_logging!
        interval = ENV["DISCOURSE_LOG_SIDEKIQ_INTERVAL"]
        return if !interval
        interval = interval.to_i
        @@interval_thread ||= Thread.new do
          begin
            loop do
              sleep interval
              mutex.synchronize do
                @@active_jobs.each { |j| j.write_to_log if j.current_duration > interval }
              end
            end
          rescue Exception => e
            Discourse.warn_exception(e, message: "Sidekiq interval logging thread terminated unexpectedly")
          end
        end
      end
    end

    include Sidekiq::Worker

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

    def self.delayed_perform(opts = {})
      self.new.perform(opts)
    end

    def execute(opts = {})
      raise "Overwrite me!"
    end

    def last_db_duration
      @db_duration || 0
    end

    def perform(*args)
      opts = args.extract_options!.with_indifferent_access

      if ::Jobs.run_later?
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
          exception = {}

          RailsMultisite::ConnectionManagement.with_connection(db) do
            job_instrumenter = JobInstrumenter.new(job_class: self.class, opts: opts, db: db, jid: jid)
            begin
              I18n.locale = SiteSetting.default_locale || SiteSettings::DefaultsProvider::DEFAULT_LOCALE
              I18n.ensure_all_loaded!
              begin
                logster_env = {}
                Logster.add_to_env(logster_env, :job, self.class.to_s)
                Logster.add_to_env(logster_env, :db, db)
                Thread.current[Logster::Logger::LOGSTER_ENV] = logster_env

                execute(opts)
              rescue => e
                exception[:ex] = e
                exception[:other] = { problem_db: db }
              end
            rescue => e
              exception[:ex] = e
              exception[:message] = "While establishing database connection to #{db}"
              exception[:other] = { problem_db: db }
            ensure
              job_instrumenter.stop(exception: exception)
            end
          end

          exceptions << exception unless exception.empty?
        end
      end

      Thread.current[Logster::Logger::LOGSTER_ENV] = nil

      if exceptions.length > 0
        exceptions.each do |exception_hash|
          Discourse.handle_job_exception(exception_hash[:ex], error_context(opts, exception_hash[:code], exception_hash[:other]))
        end
        raise HandledExceptionWrapper.new(exceptions[0][:ex])
      end

      nil
    ensure
      ActiveRecord::Base.connection_handler.clear_active_connections!
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
    extend MiniScheduler::Schedule

    def perform(*args)
      if (::Jobs::Heartbeat === self) || !Discourse.readonly_mode?
        super
      end
    end
  end

  def self.enqueue(job_name, opts = {})
    klass = "::Jobs::#{job_name.to_s.camelcase}".constantize

    # Unless we want to work on all sites
    unless opts.delete(:all_sites)
      opts[:current_site_id] ||= RailsMultisite::ConnectionManagement.current_db
    end

    # If we are able to queue a job, do it

    if ::Jobs.run_later?
      hash = {
        'class' => klass,
        'args' => [opts]
      }

      if delay = opts.delete(:delay_for)
        if delay.to_f > 0
          hash['at'] = Time.now.to_f + delay.to_f
        end
      end

      if queue = opts.delete(:queue)
        hash['queue'] = queue
      end

      klass.client_push(hash)
    else
      # Otherwise execute the job right away
      opts.delete(:delay_for)
      opts.delete(:queue)

      opts[:sync_exec] = true
      if Rails.env == "development"
        Scheduler::Defer.later("job") do
          klass.new.perform(opts)
        end
      else
        klass.new.perform(opts)
      end
    end

  end

  def self.enqueue_in(secs, job_name, opts = {})
    enqueue(job_name, opts.merge!(delay_for: secs))
  end

  def self.enqueue_at(datetime, job_name, opts = {})
    secs = [(datetime - Time.zone.now).to_i, 0].max
    enqueue_in(secs, job_name, opts)
  end

  def self.cancel_scheduled_job(job_name, opts = {})
    scheduled_for(job_name, opts).each(&:delete)
  end

  def self.scheduled_for(job_name, opts = {})
    opts = opts.with_indifferent_access
    unless opts.delete(:all_sites)
      opts[:current_site_id] ||= RailsMultisite::ConnectionManagement.current_db
    end

    job_class = "Jobs::#{job_name.to_s.camelcase}"
    Sidekiq::ScheduledSet.new.select do |scheduled_job|
      if scheduled_job.klass.to_s == job_class
        matched = true
        job_params = scheduled_job.item["args"][0].with_indifferent_access
        opts.each do |key, value|
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
