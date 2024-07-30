# frozen_string_literal: true

require_dependency "plugin_store"

module DiscourseNarrativeBot
  class Store
    def self.set(key, value)
      ::PluginStore.set(PLUGIN_NAME, key, value)
    end

    def self.get(key)
      ::PluginStore.get(PLUGIN_NAME, key)
    end

    def self.remove(key)
      ::PluginStore.remove(PLUGIN_NAME, key)
    end
  end
end
