# frozen_string_literal: true

require_dependency "plugin_store"

module DiscourseNarrativeBot
  class Store
    class << self
      def set(key, value)
        ::PluginStore.set(PLUGIN_NAME, key, value)
      end

      def get(key)
        ::PluginStore.get(PLUGIN_NAME, key)
      end

      def remove(key)
        ::PluginStore.remove(PLUGIN_NAME, key)
      end
    end
  end
end
