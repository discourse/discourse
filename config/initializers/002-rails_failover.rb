# frozen_string_literal: true

if ENV["REDIS_RAILS_FAILOVER"]
  RailsFailover::Redis.on_failover do
    Discourse.received_redis_readonly!
  end

  RailsFailover::Redis.on_fallback do
    Discourse.clear_readonly!
    Discourse.request_refresh!
  end
end

if ENV["ACTIVE_RECORD_RAILS_FAILOVER"]
  RailsFailover::ActiveRecord.on_failover do
    RailsMultisite::ConnectionManagement.each_connection do
      Discourse.enable_readonly_mode(Discourse::PG_READONLY_MODE_KEY)
      Sidekiq.pause!("pg_failover") if !Sidekiq.paused?
    end
  end

  RailsFailover::ActiveRecord.on_fallback do
    RailsMultisite::ConnectionManagement.each_connection do
      Discourse.disable_readonly_mode(Discourse::PG_READONLY_MODE_KEY)
      Sidekiq.unpause! if Sidekiq.paused?
    end
  end

  module Discourse
    PG_FORCE_READONLY_MODE_KEY ||= 'readonly_mode:postgres_force'

    READONLY_KEYS.push(PG_FORCE_READONLY_MODE_KEY)

    def self.enable_pg_force_readonly_mode
      Discourse.redis.set(PG_FORCE_READONLY_MODE_KEY, 1)
      Sidekiq.pause!("pg_failover") if !Sidekiq.paused?
      MessageBus.publish(readonly_channel, true)
      Site.clear_anon_cache!
      true
    end

    def self.disable_pg_force_readonly_mode
      result = Discourse.redis.del(PG_FORCE_READONLY_MODE_KEY)
      Sidekiq.unpause!
      MessageBus.publish(readonly_channel, false)
      result > 0
    end
  end

  RailsFailover::ActiveRecord.register_force_reading_role_callback do
    Discourse.redis.exists(
      Discourse::PG_READONLY_MODE_KEY,
      Discourse::PG_FORCE_READONLY_MODE_KEY
    )
  end
end
