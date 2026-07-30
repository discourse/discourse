# frozen_string_literal: true

module DiscourseWorkflows
  module BooleanCast
    TRUE_VALUES = [true, 1, "1", "t", "true", "y", "yes", "on"].freeze
    FALSE_VALUES = [false, 0, "0", "f", "false", "n", "no", "off", "", nil].freeze

    def self.cast!(value)
      normalized = value.is_a?(String) ? value.strip.downcase : value
      return true if TRUE_VALUES.include?(normalized)
      return false if FALSE_VALUES.include?(normalized)

      raise ArgumentError,
            I18n.t("discourse_workflows.errors.invalid_boolean", value: value.inspect)
    end
  end
end
