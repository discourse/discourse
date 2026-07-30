# frozen_string_literal: true

module DiscourseWorkflows
  module BooleanCast
    TRUE_VALUES = %w[true 1].freeze
    FALSE_VALUES = ["false", "0", ""].freeze

    def self.cast!(value)
      return value if value == true || value == false

      normalized = value.to_s.downcase
      return true if TRUE_VALUES.include?(normalized)
      return false if FALSE_VALUES.include?(normalized)

      raise ArgumentError,
            I18n.t("discourse_workflows.errors.invalid_boolean", value: value.inspect)
    end
  end
end
