# frozen_string_literal: true
require "theme_settings_object_validator"
class ObjectsSettingValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    parsed_value = val.is_a?(String) ? JSON.parse(val) : val
    if parsed_value.nil? || !parsed_value.is_a?(Array)
      @error = I18n.t("site_settings.errors.invalid_object")
      return false
    end
    errors =
      ThemeSettingsObjectValidator.validate_objects(schema: @opts[:schema], objects: parsed_value)
    if errors.empty?
      @error = nil
      true
    else
      @error = errors.map(&:full_messages).flatten.join(", ")
      false
    end
  rescue StandardError
    @error = I18n.t("site_settings.errors.invalid_object")
    false
  end

  def error_message
    @error
  end
end
