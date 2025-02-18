# frozen_string_literal: true

module Migrations::Database::Schema::Validation
  class PluginConfigValidator
    def initialize(plugin_names, errors)
      @plugin_names = plugin_names
      @errors = errors
    end

    def validate
      all_plugin_names = Discourse.plugins.map(&:name)

      if (additional_plugins = all_plugin_names - @plugin_names).any?
        @errors << I18n.t(
          "schema.validator.plugins.additional_installed",
          plugin_names: additional_plugins.sort.join(", "),
        )
      end

      if (missing_plugins = @plugin_names - all_plugin_names).any?
        @errors << I18n.t(
          "schema.validator.plugins.not_installed",
          plugin_names: missing_plugins.sort.join(", "),
        )
      end
    end
  end
end
