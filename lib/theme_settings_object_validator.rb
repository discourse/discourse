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
      next if property_attributes[:required] && validate_required_property(property_name)
      validate_property_type(property_attributes, property_name)
    end
  end

  def validate_property_type(property_attributes, property_name)
    value = @object[property_name]
    type = property_attributes[:type]

    return if (value.nil? && type != "enum")
    return if type == "objects"

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
        return
      end

    if !is_value_valid
      add_error(
        property_name,
        I18n.t("themes.settings_errors.objects.not_valid_#{type}_value", property_attributes),
      )
    end
  end

  def validate_required_property(property_name)
    if @object[property_name].nil?
      add_error(property_name, I18n.t("themes.settings_errors.objects.required"))
      true
    else
      false
    end
  end

  def add_error(property_name, error)
    @errors[property_name] ||= []
    @errors[property_name] << error
  end
end
