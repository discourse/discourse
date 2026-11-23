# frozen_string_literal: true

class EnableSsoValidator
  def initialize(opts = {})
    @opts = opts
  end

  MIN_SECRET_LENGTH = 10

  def valid_value?(val)
    return true if val == "f"
    SiteSetting.discourse_connect_url.present? && !secret_too_short?
  end

  def error_message
    if SiteSetting.discourse_connect_url.blank?
      return I18n.t("site_settings.errors.discourse_connect_url_is_empty")
    end

    I18n.t("site_settings.errors.discourse_connect_secret_is_too_short") if secret_too_short?
  end

  private

  def secret_too_short?
    SiteSetting.discourse_connect_secret.length < MIN_SECRET_LENGTH
  end
end
