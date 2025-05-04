# frozen_string_literal: true

require "sidekiq/pausable"
require "sidekiq/discourse_event"
require "sidekiq_logster_reporter"
require "sidekiq_long_running_job_logger"
require "mini_scheduler_long_running_job_logger"

Sidekiq.configure_client { |config| config.redis = Discourse.sidekiq_redis_config }

Sidekiq.configure_server do |config|
  config.redis = Discourse.sidekiq_redis_config

  config.server_middleware do |chain|
    chain.add Sidekiq::Pausable
    chain.add Sidekiq::DiscourseEvent
  end

  if stuck_sidekiq_job_minutes = GlobalSetting.sidekiq_report_long_running_jobs_minutes
    config.on(:startup) { SidekiqLongRunningJobLogger.new(stuck_sidekiq_job_minutes:).start }
  end
end

if Sidekiq.server?
  module Sidekiq
    class CLI
      private

      def print_banner
        # banner takes up too much space
      end
    end
  end

  Rails.application.config.after_initialize do
    # defer queue should simply run in sidekiq
    Scheduler::Defer.async = false

    # warm up AR
    RailsMultisite::ConnectionManagement.safe_each_connection do
      (ActiveRecord::Base.connection.tables - %w[schema_migrations versions]).each do |table|
        begin
          table.classify.constantize.first
        rescue StandardError
          nil
        end
      end
    end

    scheduler_hostname = ENV["UNICORN_SCHEDULER_HOSTNAME"]

    if !scheduler_hostname || scheduler_hostname.split(",").include?(Discourse.os_hostname)
      begin
        MiniScheduler.start(workers: GlobalSetting.mini_scheduler_workers)

        MiniSchedulerLongRunningJobLogger.new(
          poll_interval_seconds:
            ENV["DISCOURSE_MINI_SCHEDULER_LONG_RUNNING_JOB_LOGGER_POLL_INTERVAL_SECONDS"],
        ).start
      rescue MiniScheduler::DistributedMutex::Timeout
        sleep 5
        retry
      end
    end
  end
else
  # Sidekiq#logger= applies patches to whichever logger we pass it.
  # Therefore something like Sidekiq.logger = Rails.logger will break
  # all logging in the application.
  #
  # Instead, this patch adds a dedicated logger instance and patches
  # the #add method to forward messages to Rails.logger.
  Sidekiq.default_configuration.logger = Logger.new(nil)
  Sidekiq
    .default_configuration
    .logger
    .define_singleton_method(:add) do |severity, message = nil, progname = nil, &blk|
      Rails.logger.add(severity, message, progname, &blk)
    end
end

Sidekiq.default_configuration.error_handlers.clear
Sidekiq.default_configuration.error_handlers << SidekiqLogsterReporter.new

Sidekiq.strict_args!

Rails.application.config.to_prepare do
  # Ensure that scheduled jobs are loaded before mini_scheduler is configured.
  Dir.glob("#{Rails.root}/app/jobs/scheduled/*.rb") { |f| require(f) } if Rails.env.development?

  MiniScheduler.configure do |config|
    config.redis = DiscourseRedis.new(Discourse.sidekiq_redis_config)

    config.job_exception_handler { |ex, context| Discourse.handle_job_exception(ex, context) }

    config.job_ran { |stat| DiscourseEvent.trigger(:scheduled_job_ran, stat) }

    config.skip_schedule { Sidekiq.paused? }

    config.before_sidekiq_web_request do
      RailsMultisite::ConnectionManagement.establish_connection(
        db: RailsMultisite::ConnectionManagement::DEFAULT,
      )
    end
  end
end
