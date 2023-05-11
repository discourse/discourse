# frozen_string_literal: true

class EmailSettingValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    return true if val.blank?
    EmailAddressValidator.valid_value?(val)
  end

  def error_message
    I18n.t("site_settings.errors.invalid_email")
  end
end
