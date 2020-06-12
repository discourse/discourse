# frozen_string_literal: true

if ENV["REDIS_RAILS_FAILOVER"]
  message_bus_keepalive_interval = nil

  RailsFailover::Redis.on_failover do
    message_bus_keepalive_interval = MessageBus.keepalive_interval
    MessageBus.keepalive_interval = -1 # Disable MessageBus keepalive_interval
    Discourse.received_redis_readonly!
  end

  RailsFailover::Redis.on_fallback do
    Discourse.clear_redis_readonly!
    Discourse.request_refresh!
    MessageBus.keepalive_interval = message_bus_keepalive_interval
  end
end

if ENV["ACTIVE_RECORD_RAILS_FAILOVER"]
  if Rails.configuration.multisite
    if ActiveRecord::Base.current_role == ActiveRecord::Base.reading_role
      RailsMultisite::ConnectionManagement.default_connection_handler =
        ActiveRecord::Base.connection_handlers[ActiveRecord::Base.reading_role]
    end
  end

  RailsFailover::ActiveRecord.on_failover do
    RailsMultisite::ConnectionManagement.each_connection do
      Discourse.enable_readonly_mode(Discourse::PG_READONLY_MODE_KEY)
      Sidekiq.pause!("pg_failover") if !Sidekiq.paused?
    end
  rescue => e
    Rails.logger.warn "#{e.class} #{e.message}: #{e.backtrace.join("\n")}"
    false
  end

  RailsFailover::ActiveRecord.on_fallback do
    RailsMultisite::ConnectionManagement.each_connection do
      Discourse.disable_readonly_mode(Discourse::PG_READONLY_MODE_KEY)
      Sidekiq.unpause! if Sidekiq.paused?
    end

    if Rails.configuration.multisite
      RailsMultisite::ConnectionManagement.default_connection_handler =
        ActiveRecord::Base.connection_handlers[ActiveRecord::Base.writing_role]
    end
  rescue => e
    Rails.logger.warn "#{e.class} #{e.message}: #{e.backtrace.join("\n")}"
    false
  end

  module Discourse
    PG_FORCE_READONLY_MODE_KEY ||= 'readonly_mode:postgres_force'

    READONLY_KEYS.push(PG_FORCE_READONLY_MODE_KEY)

    def self.enable_pg_force_readonly_mode
      Discourse.redis.set(PG_FORCE_READONLY_MODE_KEY, 1)
      Sidekiq.pause!("pg_failover") if !Sidekiq.paused?
      MessageBus.publish(readonly_channel, true)
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
  rescue => e
    Rails.logger.warn "#{e.class} #{e.message}: #{e.backtrace.join("\n")}"
    false
  end
end
