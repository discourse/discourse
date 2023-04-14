# frozen_string_literal: true

module FlagQuery
  def self.plugin_post_custom_fields
    @plugin_post_custom_fields ||= {}
  end

  # Allow plugins to add custom fields to the flag views
  def self.register_plugin_post_custom_field(field, plugin)
    plugin_post_custom_fields[field] = plugin
  end
end
