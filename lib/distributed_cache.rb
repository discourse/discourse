# frozen_string_literal: true

require 'message_bus/distributed_cache'

class DistributedCache < MessageBus::DistributedCache
  class << self
    module Test
      def caches
        @caches ||= {}
      end

      def get(key, **opts)
        caches[key] ||= new(key, **opts)
      end

      def clear_caches!
        caches.each_value do |cache|
          cache.hash.clear
        end
      end
    end

    module Real
      def get(key, **opts)
        new(key, **opts)
      end
    end

    if Rails.env.test?
      include Test
    else
      include Real
    end
  end

  def initialize(key, manager: nil, namespace: true)
    super(
      key,
      manager: manager,
      namespace: namespace,
      app_version: Discourse.git_version
    )
  end
end
