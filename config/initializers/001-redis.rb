# frozen_string_literal: true

if Rails.env.development? && ENV['DISCOURSE_FLUSH_REDIS']
  puts "Flushing redis (development mode)"
  Discourse.redis.flushdb
end

if ENV['RAILS_FAILOVER']
  message_bus_keepalive_interval = MessageBus.keepalive_interval

  RailsFailover::Redis.register_master_up_callback do
    MessageBus.keepalive_interval = message_bus_keepalive_interval
    Discourse.clear_readonly!
    Discourse.request_refresh!
  end

  RailsFailover::Redis.register_master_down_callback do
    # Disables MessageBus keepalive when Redis is in readonly mode
    MessageBus.keepalive_interval = 0
  end
end
