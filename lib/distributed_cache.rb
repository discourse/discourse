# frozen_string_literal: true

require 'message_bus/distributed_cache'

class DistributedCache < MessageBus::DistributedCache
  module Mixin
    module Test
      module ClassMethods
        def caches
          @caches ||= {}
        end

        def clear_caches!
          caches.clear
        end
      end

      def self.included(base)
        base.extend ClassMethods
      end

      def distributed_cache(name, key, **opts)
        define_singleton_method(name) do
          DistributedCache::Mixin.caches[object_id] ||= {}
          DistributedCache::Mixin.caches[object_id][name] ||= DistributedCache.new(key, **opts)
        end
      end
    end

    module Real
      def distributed_cache(name, key, **opts)
        define_singleton_method(name) do
          @__distributed_caches ||= {}
          @__distributed_caches[name] ||= DistributedCache.new(key, **opts)
        end
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
