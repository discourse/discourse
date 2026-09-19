# frozen_string_literal: true

class DiscourseChatIntegration::PluginModel < PluginStoreRow
  PLUGIN_NAME = "discourse-chat-integration"

  default_scope { default_scope }

  after_initialize :init_plugin_model
  before_save :set_key

  def self.default_scope
    where(type_name: "JSON").where(plugin_name: self::PLUGIN_NAME).where(
      "key LIKE ?",
      "#{key_prefix}%",
    )
  end

  def self.key_prefix
    raise "Not implemented"
  end

  private

  def set_key
    self.key ||= self.class.alloc_key
  end

  def init_plugin_model
    self.type_name ||= "JSON"
    self.plugin_name ||= PLUGIN_NAME
  end

  def self.alloc_key
    DistributedMutex.synchronize("#{self::PLUGIN_NAME}_#{key_prefix}_id") do
      max_id = PluginStore.get(self::PLUGIN_NAME, "#{key_prefix}_id")
      max_id = 1 unless max_id
      PluginStore.set(self::PLUGIN_NAME, "#{key_prefix}_id", max_id + 1)
      "#{key_prefix}#{max_id}"
    end
  end
end
