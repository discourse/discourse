# frozen_string_literal: true

module FlagQuery
  class << self
    def plugin_post_custom_fields
      @plugin_post_custom_fields ||= {}
    end

    # Allow plugins to add custom fields to the flag views
    def register_plugin_post_custom_field(field, plugin)
      plugin_post_custom_fields[field] = plugin
    end
  end
end
