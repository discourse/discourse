require "sidekiq/pausable"

sidekiq_redis = { url: $redis.url, namespace: 'sidekiq' }

Sidekiq.configure_client do |config|
  config.redis = sidekiq_redis
end

Sidekiq.configure_server do |config|
  config.redis = sidekiq_redis

  database_url = ENV['DATABASE_URL']
  sidekiq_concurrency = ENV['WORKER_CONCURRENCY'] ? (ENV['WORKER_CONCURRENCY'].to_i + 5) : 5
  if(database_url && sidekiq_concurrency)
    Rails.logger.debug("Setting custom connection pool size of #{sidekiq_concurrency} for Sidekiq Server")
    ENV['DATABASE_URL'] = "#{database_url}?pool=#{sidekiq_concurrency}"
    ActiveRecord::Base.establish_connection
  end
  Rails.logger.info("Connection Pool size for Sidekiq Server is now: #{ActiveRecord::Base.connection.pool.instance_variable_get('@size')}")

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

Sidekiq.logger.level = Logger::WARN
