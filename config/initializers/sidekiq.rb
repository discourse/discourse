sidekiq_redis = { url: $redis.url, namespace: 'sidekiq' }

Sidekiq.configure_server do |config|
  config.redis = sidekiq_redis
  Sidetiq::Clock.start!
end

Sidetiq.configure do |config|
  # we only check for new jobs once every 5 seconds
  # to cut down on cpu cost
  config.resolution = 5
end

Sidekiq.configure_client { |config| config.redis = sidekiq_redis }
Sidekiq.logger.level = Logger::WARN
