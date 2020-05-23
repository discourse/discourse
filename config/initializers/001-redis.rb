# frozen_string_literal: true

if Rails.env.development? && ENV['DISCOURSE_FLUSH_REDIS']
  puts "Flushing redis (development mode)"
  Discourse.redis.flushall
end
