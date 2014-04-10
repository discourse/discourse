require "sidekiq/pausable"

sidekiq_redis = { url: $redis.url, namespace: 'sidekiq' }

Sidekiq.configure_client do |config|
  config.redis = sidekiq_redis
end

Sidekiq.configure_server do |config|
  config.redis = sidekiq_redis
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
