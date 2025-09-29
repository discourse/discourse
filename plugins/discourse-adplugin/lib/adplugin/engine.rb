# frozen_string_literal: true

module AdPlugin
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace AdPlugin
  end

  def self.pstore_get(key)
    PluginStore.get(PLUGIN_NAME, key)
  end

  def self.pstore_set(key, value)
    PluginStore.set(PLUGIN_NAME, key, value)
  end

  def self.pstore_delete(key)
    PluginStore.remove(PLUGIN_NAME, key)
  end
end
