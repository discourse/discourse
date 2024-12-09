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

  def self.with_immediate_jobs
    prior = @run_immediately
    run_immediately!
    yield
  ensure
    @run_immediately = prior
  end

  def self.last_job_performed_at
    Sidekiq.redis do |r|
      int = r.get("last_job_perform_at")
      int ? Time.at(int.to_i) : nil
    end
  end

  def self.num_email_retry_jobs
    Sidekiq::RetrySet.new.count { |job| job.klass =~ /Email\z/ }
  end

  class Base
    class JobInstrumenter
      def initialize(job_class:, opts:, db:, jid:)
        return unless enabled?

        self.class.mutex.synchronize do
          @data = {}

          @data["hostname"] = Discourse.os_hostname
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
          @data["live_slots_start"] = GC.stat[:heap_live_slots]
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
          @data["live_slots_finish"] = GC.stat[:heap_live_slots]
          @data["live_slots"] = @data["live_slots_finish"] - @data["live_slots_start"]

          if exception.present?
            @data["exception"] = exception # Exception - if job fails a json encoded exception
            @data["status"] = "failed"
          else
            @data["status"] = "success" # Status - fail, success, pending
          end

          write_to_log
        end
      end

      def self.raw_log(message)
        begin
          logger << message
        rescue => e
          Discourse.warn_exception(e, message: "Exception encountered while logging Sidekiq job")
        end
      end

      def self.logger
        @@logger ||= Logger.new("#{Rails.root}/log/sidekiq.log")
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
        Discourse.enable_sidekiq_logging?
      end

      def self.mutex
        @@mutex ||= Mutex.new
      end

      def self.ensure_interval_logging!
        interval = ENV["DISCOURSE_LOG_SIDEKIQ_INTERVAL"]
        return if !interval
        interval = interval.to_i
        @@interval_thread ||=
          Thread.new do
            begin
              loop do
                sleep interval
                mutex.synchronize do
                  @@active_jobs.each { |j| j.write_to_log if j.current_duration > interval }
                end
              end
            rescue Exception => e
              Discourse.warn_exception(
                e,
                message: "Sidekiq interval logging thread terminated unexpectedly",
              )
            end
          end
      end
    end

    include Sidekiq::Worker

    def self.cluster_concurrency(val)
      raise ArgumentError, "cluster_concurrency must be 1 or nil" if val != 1 && val != nil
      @cluster_concurrency = val
    end

    def self.get_cluster_concurrency
      @cluster_concurrency
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

    def self.delayed_perform(opts = {})
      self.new.perform(opts)
    end

    def execute(opts = {})
      raise "Overwrite me!"
    end

    def last_db_duration
      @db_duration || 0
    end

    def perform_immediately(*args)
      opts = args.extract_options!.with_indifferent_access

      if opts.has_key?(:current_site_id) &&
           opts[:current_site_id] != RailsMultisite::ConnectionManagement.current_db
        raise ArgumentError.new(
                "You can't connect to another database when executing a job synchronously.",
              )
      else
        begin
          retval = execute(opts)
        rescue => exc
          Discourse.handle_job_exception(exc, error_context(opts))
        end

        retval
      end
    end

    def self.cluster_concurrency_redis_key
      "cluster_concurrency:#{self}"
    end

    def self.clear_cluster_concurrency_lock!
      Discourse.redis.without_namespace.del(cluster_concurrency_redis_key)
    end

    def self.acquire_cluster_concurrency_lock!
      !!Discourse.redis.without_namespace.set(cluster_concurrency_redis_key, 0, nx: true, ex: 120)
    end

    def perform(*args)
      requeued = false
      keepalive_thread = nil
      finished = false

      if self.class.get_cluster_concurrency
        if !self.class.acquire_cluster_concurrency_lock!
          self.class.perform_in(10.seconds, *args)
          requeued = true
          return
        end

        parent_thread = Thread.current
        cluster_concurrency_redis_key = self.class.cluster_concurrency_redis_key

        keepalive_thread =
          Thread.new do
            while parent_thread.alive? && !finished
              Discourse.redis.without_namespace.expire(cluster_concurrency_redis_key, 120)

              # Sleep for 60 seconds, but wake up every second to check if the job has been completed
              60.times do
                break if finished
                sleep 1
              end
            end
          end
      end

      opts = args.extract_options!.with_indifferent_access

      Sidekiq.redis { |r| r.set("last_job_perform_at", Time.now.to_i) } if ::Jobs.run_later?

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
            job_instrumenter =
              JobInstrumenter.new(job_class: self.class, opts: opts, db: db, jid: jid)
            begin
              I18n.locale =
                SiteSetting.default_locale || SiteSettings::DefaultsProvider::DEFAULT_LOCALE
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
          Discourse.handle_job_exception(
            exception_hash[:ex],
            error_context(opts, exception_hash[:code], exception_hash[:other]),
          )
        end
        raise HandledExceptionWrapper.new(exceptions[0][:ex])
      end

      nil
    ensure
      if self.class.get_cluster_concurrency && !requeued
        finished = true
        keepalive_thread.wakeup
        keepalive_thread.join
        self.class.clear_cluster_concurrency_lock!
      end

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
      super if (::Jobs::Heartbeat === self) || !Discourse.readonly_mode?
    end
  end

  def self.enqueue(job, opts = {})
    if job.instance_of?(Class)
      klass = job
    else
      klass = "::Jobs::#{job.to_s.camelcase}".constantize
    end

    # Unless we want to work on all sites
    unless opts.delete(:all_sites)
      opts[:current_site_id] ||= RailsMultisite::ConnectionManagement.current_db
    end

    delay = opts.delete(:delay_for)
    queue = opts.delete(:queue)

    # Only string keys are allowed in JSON. We call `.with_indifferent_access`
    # in Jobs::Base#perform, so this is invisible to developers
    opts = opts.deep_stringify_keys

    # Simulate the args being dumped/parsed through JSON
    parsed_opts = JSON.parse(JSON.dump(opts))
    if opts != parsed_opts
      Discourse.deprecate(<<~TEXT.squish, since: "2.9", drop_from: "3.0", output_in_test: true)
        #{klass.name} was enqueued with argument values which do not cleanly serialize to/from JSON.
        This means that the job will be run with slightly different values than the ones supplied to `enqueue`.
        Argument values should be strings, booleans, numbers, or nil (or arrays/hashes of those value types).
      TEXT
    end
    opts = parsed_opts

    if ::Jobs.run_later?
      hash = { "class" => klass, "args" => [opts] }

      if delay
        hash["at"] = Time.now.to_f + delay.to_f if delay.to_f > 0
      end

      hash["queue"] = queue if queue

      DB.after_commit { klass.client_push(hash) }
    else
      if Rails.env == "development"
        Scheduler::Defer.later("job") { klass.new.perform(opts) }
      else
        # Run the job synchronously
        # But never run a job inside another job
        # That could cause deadlocks during test runs
        queue = Thread.current[:discourse_nested_job_queue]
        outermost_job = !queue

        if outermost_job
          queue = Queue.new
          Thread.current[:discourse_nested_job_queue] = queue
        end

        queue.push([klass, opts])

        if outermost_job
          # responsible for executing the queue
          begin
            until queue.empty?
              queued_klass, queued_opts = queue.pop(true)
              queued_klass.new.perform_immediately(queued_opts)
            end
          ensure
            Thread.current[:discourse_nested_job_queue] = nil
          end
        end
      end
    end
  end

  def self.enqueue_in(secs, job_name, opts = {})
    enqueue(job_name, opts.merge!(delay_for: secs))
  end

  def self.enqueue_at(datetime, job_name, opts = {})
    secs = [datetime.to_f - Time.zone.now.to_f, 0].max
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
