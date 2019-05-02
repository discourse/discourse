# frozen_string_literal: true

require "net/pop"

class POP3PollingEnabledSettingValidator

  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    # only validate when enabling polling
    return true if val == "f"
    # ensure we can authenticate
    SiteSetting.pop3_polling_host.present? &&
    SiteSetting.pop3_polling_username.present? &&
    SiteSetting.pop3_polling_password.present? &&
    authentication_works?
  end

  def error_message
    if SiteSetting.pop3_polling_host.blank?
      I18n.t("site_settings.errors.pop3_polling_host_is_empty")
    elsif SiteSetting.pop3_polling_username.blank?
      I18n.t("site_settings.errors.pop3_polling_username_is_empty")
    elsif SiteSetting.pop3_polling_password.blank?
      I18n.t("site_settings.errors.pop3_polling_password_is_empty")
    elsif !authentication_works?
      I18n.t("site_settings.errors.pop3_polling_authentication_failed")
    end
  end

  private

  def authentication_works?
    @authentication_works ||= begin
      pop3 = Net::POP3.new(SiteSetting.pop3_polling_host, SiteSetting.pop3_polling_port)
      pop3.enable_ssl(OpenSSL::SSL::VERIFY_NONE) if SiteSetting.pop3_polling_ssl
      pop3.auth_only(SiteSetting.pop3_polling_username, SiteSetting.pop3_polling_password)
    rescue Net::POPAuthenticationError
      false
    else
      true
    end
  end
end
