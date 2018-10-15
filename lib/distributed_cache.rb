# frozen_string_literal: true

require 'message_bus/distributed_cache'

class DistributedCache < MessageBus::DistributedCache
  def initialize(key, manager: nil, namespace: true)
    super(
      key,
      manager: manager,
      namespace: namespace,
      app_version: Discourse.git_version
    )
  end
end
