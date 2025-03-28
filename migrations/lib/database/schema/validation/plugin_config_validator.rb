# frozen_string_literal: true

module Migrations::Database::Schema::Validation
  class PluginConfigValidator < BaseValidator
    def initialize(config, errors)
      super(config, errors, nil)
    end

    def validate
      all_plugin_names = Discourse.plugins.map(&:name)
      configured_plugin_names = @config[:plugins]

      if (additional_plugins = all_plugin_names - configured_plugin_names).any?
        @errors << I18n.t(
          "schema.validator.plugins.additional_installed",
          plugin_names: sort_and_join(additional_plugins),
        )
      end

      if (missing_plugins = configured_plugin_names - all_plugin_names).any?
        @errors << I18n.t(
          "schema.validator.plugins.not_installed",
          plugin_names: sort_and_join(missing_plugins),
        )
      end
    end
  end
end
