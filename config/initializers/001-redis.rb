# frozen_string_literal: true

if Rails.env.development? && ENV['DISCOURSE_FLUSH_REDIS']
  puts "Flushing redis (development mode)"
  Discourse.redis.flushdb
end

# Pending https://github.com/MiniProfiler/rack-mini-profiler/pull/450 and
# upgrade to Sidekiq 6.1
Redis.exists_returns_integer = true
