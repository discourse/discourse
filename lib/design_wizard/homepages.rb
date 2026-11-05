# frozen_string_literal: true

module DesignWizard
  class Homepages
    def self.additional_options
      return [] if !SiteSetting.concord_in_wizard

      DiscoursePluginRegistry.apply_modifier(:design_wizard_homepages, [])
    end

    def self.ids
      %w[latest new hot categories] + additional_options.map { |option| option[:id] }
    end

    def self.current_settings
      additional_options
        .flat_map { |option| option.fetch(:settings, {}).keys }
        .uniq
        .index_with { |name| SiteSetting.public_send(name) }
    end

    def self.settings_for(id, overrides: {})
      defaults = additional_options.find { |option| option[:id] == id }&.fetch(:settings, {}) || {}
      defaults = {} if id == SiteSetting.homepage
      defaults.merge(overrides)
    end
  end
end
