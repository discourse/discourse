# frozen_string_literal: true

class UrlSettingValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    val.blank? || UrlHelper.is_valid_url?(val)
  end

  def error_message
    I18n.t("site_settings.errors.invalid_url")
  end
end
