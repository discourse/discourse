# frozen_string_literal: true

module DesignWizard
  class Homepages
    def self.additional_options
      DiscoursePluginRegistry.apply_modifier(:design_wizard_homepages, [])
    end

    def self.ids
      %w[latest new hot categories] + additional_options.map { |option| option[:id] }
    end

    def self.settings_for(id)
      additional_options.find { |option| option[:id] == id }&.fetch(:settings, {}) || {}
    end
  end
end
