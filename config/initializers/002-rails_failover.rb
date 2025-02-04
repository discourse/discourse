# frozen_string_literal: true

if defined?(RailsFailover::Redis)
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

    ObjectSpace.each_object(DistributedCache) { |cache| cache.clear }

    SiteSetting.refresh!
  end

  RailsFailover::Redis.logger = Rails.logger.broadcasts.first
end

if defined?(RailsFailover::ActiveRecord)
  return unless Rails.configuration.active_record_rails_failover

  if Rails.configuration.multisite
    if ActiveRecord::Base.current_role == ActiveRecord.reading_role
      RailsMultisite::ConnectionManagement.default_connection_handler =
        ActiveRecord::Base.connection_handlers[ActiveRecord.reading_role]
    end
  end

  RailsFailover::ActiveRecord.on_failover do |role|
    if role == ActiveRecord.writing_role # Multisite master
      RailsMultisite::ConnectionManagement.each_connection do
        Discourse.enable_readonly_mode(Discourse::PG_READONLY_MODE_KEY)
      end
    else
      ActiveRecord::Base.connected_to(role: role) do
        Discourse.enable_readonly_mode(Discourse::PG_READONLY_MODE_KEY)
      end

      # Test connection to the master, and trigger master failover if needed
      ActiveRecord::Base.connected_to(role: ActiveRecord.writing_role) do
        ActiveRecord::Base.connection.connect!.active?
      rescue PG::ConnectionBad, PG::UnableToSend, PG::ServerError
        RailsFailover::ActiveRecord.verify_primary(ActiveRecord.writing_role)
      end
    end
  end

  RailsFailover::ActiveRecord.on_fallback do |role|
    if role == ActiveRecord.writing_role # Multisite master
      RailsMultisite::ConnectionManagement.each_connection do
        Discourse.disable_readonly_mode(Discourse::PG_READONLY_MODE_KEY)
      end
    else
      ActiveRecord::Base.connected_to(role: role) do
        Discourse.disable_readonly_mode(Discourse::PG_READONLY_MODE_KEY)
      end
    end

    if Rails.configuration.multisite
      RailsMultisite::ConnectionManagement.default_connection_handler =
        ActiveRecord::Base.connection_handlers[ActiveRecord.writing_role]
    end
  end

  RailsFailover::ActiveRecord.register_force_reading_role_callback do
    GlobalSetting.pg_force_readonly_mode ||
      Discourse.redis.exists?(
        Discourse::PG_READONLY_MODE_KEY,
        Discourse::PG_FORCE_READONLY_MODE_KEY,
      )
  rescue => e
    if !e.is_a?(Redis::CannotConnectError)
      Rails.logger.warn "#{e.class} #{e.message}: #{e.backtrace.join("\n")}"
    end

    false
  end
end
