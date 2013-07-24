sidekiq_redis = { url: $redis.url, namespace: 'sidekiq' }

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
  Sidetiq::Clock.start!
end

Sidetiq.configure do |config|
  # we only check for new jobs once every 5 seconds
  # to cut down on cpu cost
  config.resolution = 5
end

Sidekiq.configure_client { |config| config.redis = sidekiq_redis }
Sidekiq.logger.level = Logger::WARN
