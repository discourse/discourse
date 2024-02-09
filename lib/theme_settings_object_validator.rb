# frozen_string_literal: true

class ThemeSettingsObjectValidator
  def initialize(schema:, object:)
    @object = object
    @schema_name = schema[:name]
    @properties = schema[:properties]
    @errors = {}
  end

  def validate
    validate_required_properties

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

  def validate_required_properties
    @properties.each do |property_name, property_attributes|
      if property_attributes[:required] && @object[property_name].nil?
        @errors[property_name] ||= []
        @errors[property_name] << I18n.t("themes.settings_errors.objects.required")
      end
    end
  end
end
