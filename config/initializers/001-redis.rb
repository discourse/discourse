# frozen_string_literal: true

if Rails.env.development? && ENV["DISCOURSE_FLUSH_REDIS"]
  puts "Flushing redis (development mode)"
  Discourse.redis.flushdb
end

begin
  if Gem::Version.new(Discourse.redis.info["redis_version"]) < Gem::Version.new("6.2.0")
    STDERR.puts "Discourse requires Redis 6.2.0 or up"
    exit 1
  end
rescue Redis::CannotConnectError
  STDERR.puts "Couldn't connect to Redis"
end
