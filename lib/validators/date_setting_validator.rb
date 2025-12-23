# frozen_string_literal: true

class DateSettingValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    return true if val.blank?

    begin
      true if Date.parse(val)
    rescue StandardError
      false
    end
  end

  def error_message
    I18n.t("site_settings.errors.invalid_date")
  end
end
