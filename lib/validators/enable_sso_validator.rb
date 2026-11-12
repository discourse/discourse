# frozen_string_literal: true

class EnableSsoValidator
  def initialize(opts = {})
    @opts = opts
  end

  MIN_SECRET_LENGTH = 10

  def valid_value?(val)
    return true if val == "f"
    if SiteSetting.discourse_connect_url.blank? || secret_too_short? || is_2fa_enforced?
      return false
    end
    true
  end

  def error_message
    if SiteSetting.discourse_connect_url.blank?
      return I18n.t("site_settings.errors.discourse_connect_url_is_empty")
    end

    return I18n.t("site_settings.errors.discourse_connect_secret_is_too_short") if secret_too_short?

    if is_2fa_enforced?
      I18n.t("site_settings.errors.discourse_connect_cannot_be_enabled_if_second_factor_enforced")
    end
  end

  def is_2fa_enforced?
    SiteSetting.enforce_second_factor? != "no"
  end

  private

  def secret_too_short?
    SiteSetting.discourse_connect_secret.length < MIN_SECRET_LENGTH
  end
end
