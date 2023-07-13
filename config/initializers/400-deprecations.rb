# frozen_string_literal: true

if !GlobalSetting.skip_redis?
  if GlobalSetting.respond_to?(:redis_slave_host) && GlobalSetting.redis_slave_host.present?
    Discourse.deprecate(
      "redis_slave_host is deprecated, use redis_replica_host instead",
      drop_from: "2.8",
    )
  end

  if GlobalSetting.respond_to?(:redis_slave_port) && GlobalSetting.redis_slave_port.present?
    Discourse.deprecate(
      "redis_slave_port is deprecated, use redis_replica_port instead",
      drop_from: "2.8",
    )
  end

  if GlobalSetting.respond_to?(:message_bus_redis_slave_host) &&
       GlobalSetting.message_bus_redis_slave_host.present?
    Discourse.deprecate(
      "message_bus_redis_slave_host is deprecated, use message_bus_redis_replica_host",
      drop_from: "2.8",
    )
  end

  if GlobalSetting.respond_to?(:message_bus_redis_slave_port) &&
       GlobalSetting.message_bus_redis_slave_port.present?
    Discourse.deprecate(
      "message_bus_redis_slave_port is deprecated, use message_bus_redis_replica_port",
      drop_from: "2.8",
    )
  end
end
