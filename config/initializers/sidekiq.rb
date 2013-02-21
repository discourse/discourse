require "#{Rails.root}/lib/discourse_redis"

$redis = DiscourseRedis.new

if Rails.env.development? and !ENV['DO_NOT_FLUSH_REDIS']
  puts "Flushing redis (development mode)"
  $redis.flushall
end

Sidekiq.configure_server do |config|
  config.redis = { :url => $redis.url, :namespace => 'sidekiq' }
end

Sidekiq.configure_client do |config|
  config.redis = { :url => $redis.url, :namespace => 'sidekiq' }
end