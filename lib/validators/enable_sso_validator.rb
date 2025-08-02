# frozen_string_literal: true

class EnableSsoValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    return true if val == "f"
    return false if SiteSetting.discourse_connect_url.blank? || is_2fa_enforced?
    true
  end

  def error_message
    if SiteSetting.discourse_connect_url.blank?
      return I18n.t("site_settings.errors.discourse_connect_url_is_empty")
    end

    if is_2fa_enforced?
      I18n.t("site_settings.errors.discourse_connect_cannot_be_enabled_if_second_factor_enforced")
    end
  end

  def is_2fa_enforced?
    SiteSetting.enforce_second_factor? != "no"
  end
end
