# frozen_string_literal: true

# Service class that holds helper methods that can be used to validate theme settings.
class ThemeSettingsValidator
  class << self
    def is_value_present?(value)
      !value.nil?
    end

    def is_valid_value_type?(value, type)
      case type
      when self.types[:integer]
        value.is_a?(Integer)
      when self.types[:float]
        value.is_a?(Integer) || value.is_a?(Float)
      when self.types[:bool]
        value.is_a?(TrueClass) || value.is_a?(FalseClass)
      when self.types[:list]
        value.is_a?(String)
      when self.types[:objects]
        value.is_a?(Array) && value.all? { |v| v.is_a?(Hash) }
      else
        true
      end
    end

    def validate_value(value, type, opts)
      errors = []

      case type
      when types[:enum]
        if opts[:choices].exclude?(value) && opts[:choices].map(&:to_s).exclude?(value)
          errors << I18n.t(
            "themes.settings_errors.enum_value_not_valid",
            choices: opts[:choices].join(", "),
          )
        end
      when types[:integer], types[:float]
        validate_value_in_range!(
          value,
          min: opts[:min],
          max: opts[:max],
          errors:,
          translation_prefix: "number",
        )
      when types[:string]
        validate_value_in_range!(
          value.to_s.length,
          min: opts[:min],
          max: opts[:max],
          errors:,
          translation_prefix: "string",
        )
      when types[:objects]
        errors.concat(
          SchemaSettingsObjectValidator.validate_objects(schema: opts[:schema], objects: value),
        )
      end

      errors
    end

    private

    def types
      ThemeSetting.types
    end

    def validate_value_in_range!(value, min:, max:, errors:, translation_prefix:)
      if min && max && max != Float::INFINITY && !(min..max).include?(value)
        errors << I18n.t(
          "themes.settings_errors.#{translation_prefix}_value_not_valid_min_max",
          min: min,
          max: max,
        )
      elsif min && value < min
        errors << I18n.t(
          "themes.settings_errors.#{translation_prefix}_value_not_valid_min",
          min: min,
        )
      elsif max && value > max
        errors << I18n.t(
          "themes.settings_errors.#{translation_prefix}_value_not_valid_max",
          max: max,
        )
      end
    end
  end
end
