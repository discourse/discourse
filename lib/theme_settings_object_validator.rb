# frozen_string_literal: true

class ThemeSettingsObjectValidator
  def initialize(schema:, object:)
    @object = object
    @schema_name = schema[:name]
    @properties = schema[:properties]
    @errors = {}
  end

  def validate
    validate_properties

    @properties.each do |property_name, property_attributes|
      if property_attributes[:type] == "objects"
        @object[property_name]&.each do |child_object|
          @errors[property_name] ||= []

          @errors[property_name].push(
            self.class.new(schema: property_attributes[:schema], object: child_object).validate,
          )
        end
      end
    end

    @errors
  end

  private

  def validate_properties
    @properties.each do |property_name, property_attributes|
      next if property_attributes[:required] && !is_property_present?(property_name)
      next if !has_valid_property_value_type?(property_attributes, property_name)
      next if !has_valid_property_value?(property_attributes, property_name)
    end
  end

  def has_valid_property_value_type?(property_attributes, property_name)
    value = @object[property_name]
    type = property_attributes[:type]

    return true if (value.nil? && type != "enum")
    return true if type == "objects"

    is_value_valid =
      case type
      when "string"
        value.is_a?(String)
      when "integer"
        value.is_a?(Integer)
      when "float"
        value.is_a?(Float) || value.is_a?(Integer)
      when "boolean"
        [true, false].include?(value)
      when "enum"
        property_attributes[:choices].include?(value)
      else
        add_error(property_name, I18n.t("themes.settings_errors.objects.invalid_type", type:))
        return false
      end

    if is_value_valid
      true
    else
      add_error(
        property_name,
        I18n.t("themes.settings_errors.objects.not_valid_#{type}_value", property_attributes),
      )
      false
    end
  end

  def has_valid_property_value?(property_attributes, property_name)
    validations = property_attributes[:validations]

    return true if validations.blank?

    type = property_attributes[:type]
    value = @object[property_name]

    case type
    when "string"
      if validations[:min_length] && value.length < validations[:min_length]
        add_error(
          property_name,
          I18n.t(
            "themes.settings_errors.objects.string_value_not_valid_min",
            min: validations[:min_length],
          ),
        )

        return false
      end

      if validations[:max_length] && value.length > validations[:max_length]
        add_error(
          property_name,
          I18n.t(
            "themes.settings_errors.objects.string_value_not_valid_max",
            max: validations[:max_length],
          ),
        )

        return false
      end

      if validations[:url] && !value.match?(URI.regexp)
        add_error(
          property_name,
          I18n.t("themes.settings_errors.objects.string_value_not_valid_url"),
        )

        return false
      end
    when "integer", "float"
      if validations[:min] && value < validations[:min]
        add_error(
          property_name,
          I18n.t(
            "themes.settings_errors.objects.number_value_not_valid_min",
            min: validations[:min],
          ),
        )

        return false
      end

      if validations[:max] && value > validations[:max]
        add_error(
          property_name,
          I18n.t(
            "themes.settings_errors.objects.number_value_not_valid_max",
            max: validations[:max],
          ),
        )

        return false
      end
    end

    true
  end

  def is_property_present?(property_name)
    if @object[property_name].nil?
      add_error(property_name, I18n.t("themes.settings_errors.objects.required"))
      false
    else
      true
    end
  end

  def add_error(property_name, error)
    @errors[property_name] ||= []
    @errors[property_name] << error
  end
end
