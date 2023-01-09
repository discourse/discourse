# frozen_string_literal: true

require "message_bus/distributed_cache"

class DistributedCache < MessageBus::DistributedCache
  def initialize(key, manager: nil, namespace: true)
    super(key, manager: manager, namespace: namespace, app_version: Discourse.git_version)
  end

  # Defer setting of the key in the cache for performance critical path to avoid
  # waiting on MessageBus to publish the message which involves writing to Redis.
  def defer_set(k, v)
    Scheduler::Defer.later("#{@key}_set") { self[k] = v }
  end

  def defer_get_set(k, &block)
    return self[k] if hash.key? k
    value = block.call
    self.defer_set(k, value)
    value
  end
end
