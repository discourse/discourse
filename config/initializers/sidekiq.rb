require "sidekiq/pausable"

Sidekiq.configure_client do |config|
  config.redis = Discourse.sidekiq_redis_config
end

Sidekiq.configure_server do |config|
  config.redis = Discourse.sidekiq_redis_config
  # add our pausable middleware
  config.server_middleware do |chain|
    chain.add Sidekiq::Pausable
  end
end

if Sidekiq.server?

  # warm up AR
  RailsMultisite::ConnectionManagement.each_connection do
    (ActiveRecord::Base.connection.tables - %w[schema_migrations]).each do |table|
      table.classify.constantize.first rescue nil
    end
  end

  Rails.application.config.after_initialize do
    require 'scheduler/scheduler'
    manager = Scheduler::Manager.new
    Scheduler::Manager.discover_schedules.each do |schedule|
      manager.ensure_schedule!(schedule)
    end
    Thread.new do
      while true
        begin
          manager.tick
        rescue => e
          # the show must go on
          Discourse.handle_exception(e)
        end
        sleep 1
      end
    end
  end
end

Sidekiq.logger.level = Logger::WARN

class LogsterErrorHandler
  def call(ex, hash={})
    text = "exception: #{ex}\ncontext: #{hash.inspect}\n"
    if ex.backtrace
      text << "backtrace: #{ex.backtrace.join("\n")}"
    end
    Rails.logger.error(text)
  rescue => e
    Rails.logger.fatal("Failed to log exception #{ex} #{hash}\nReason: #{e}\n#{e.backtrace.join("\n")}")
  end
end

Sidekiq.error_handlers << LogsterErrorHandler.new


