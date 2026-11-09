# frozen_string_literal: true

module DesignWizard
  class Homepages
    def self.additional_options
      return [] if !SiteSetting.concord_in_wizard

      DiscoursePluginRegistry.apply_modifier(:design_wizard_homepages, [])
    end

    def self.ids
      %w[latest categories] + additional_options.map { |option| option[:id] }
    end

    # a revert has to put back a topic list homepage the wizard no longer offers;
    # plugin homepages stay limited to `ids`, which only lists them while usable
    def self.restorable_ids
      ids | TopMenu.homepage_choices
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
