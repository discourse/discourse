sidekiq_redis = { url: $redis.url, namespace: 'sidekiq' }

Sidekiq.configure_server { |config| config.redis = sidekiq_redis }
Sidekiq.configure_client { |config| config.redis = sidekiq_redis }

Sidekiq.logger.level = Logger::WARN
