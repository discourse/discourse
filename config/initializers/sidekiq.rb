sidekiq_redis = { url: $redis.url, namespace: 'sidekiq' }

Sidekiq.configure_server do |config|
  config.redis = sidekiq_redis
end

if Sidekiq.server?

  # warm up AR
  RailsMultisite::ConnectionManagement.each_connection do
    (ActiveRecord::Base.connection.tables - %w[schema_migrations]).each do |table|
      table.classify.constantize.first rescue nil
    end
  end

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
        Scheduler::Manager.handle_exception(e)
      end
      sleep 1
    end
  end
end

Sidekiq.configure_client { |config| config.redis = sidekiq_redis }
Sidekiq.logger.level = Logger::WARN

