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
    validate_no_oauth2 =
      SiteSetting.pop3_polling_host.present? && SiteSetting.pop3_polling_username.present? &&
        SiteSetting.pop3_polling_password.present?
    validate_oauth2 =
      SiteSetting.pop3_polling_host.present? && SiteSetting.pop3_polling_oauth2_scope.present? &&
        SiteSetting.pop3_polling_oauth2_endpoint.present? &&
        SiteSetting.pop3_polling_oauth2_clientid.present? &&
        SiteSetting.pop3_polling_username.present? &&
        SiteSetting.pop3_polling_oauth2_refresh_token.present?

    (
      (!SiteSetting.pop3_polling_oauth2 && validate_no_oauth2) ||
        (SiteSetting.pop3_polling_oauth2 && validate_oauth2)
    ) && authentication_works?
  end

  def error_message
    if !SiteSetting.pop3_polling_oauth2?
      if SiteSetting.pop3_polling_host.blank?
        I18n.t("site_settings.errors.pop3_polling_host_is_empty")
      elsif SiteSetting.pop3_polling_username.blank?
        I18n.t("site_settings.errors.pop3_polling_username_is_empty")
      elsif SiteSetting.pop3_polling_password.blank?
        I18n.t("site_settings.errors.pop3_polling_password_is_empty")
      elsif !authentication_works?
        I18n.t("site_settings.errors.pop3_polling_authentication_failed")
      end
    else
      if SiteSetting.pop3_polling_host.blank?
        I18n.t("site_settings.errors.pop3_polling_host_is_empty")
      elsif SiteSetting.pop3_polling_username.blank?
        I18n.t("site_settings.errors.pop3_polling_username_is_empty")
      elsif SiteSetting.pop3_polling_oauth2_scope.blank?
        I18n.t("site_settings.errors.pop3_polling_oauth2_scope_is_empty")
      elsif SiteSetting.pop3_polling_oauth2_endpoint.blank?
        I18n.t("site_settings.errors.pop3_polling_oauth2_endpoint_is_empty")
      elsif SiteSetting.pop3_polling_oauth2_clientid.blank?
        I18n.t("site_settings.errors.pop3_polling_oauth2_clientid_is_empty")
      elsif SiteSetting.pop3_polling_oauth2_refresh_token.blank?
        I18n.t("site_settings.errors.pop3_polling_oauth2_refresh_token_is_empty")
      elsif !authentication_works?
        I18n.t("site_settings.errors.pop3_polling_authentication_failed")
      end
    end
  end

  private

  def authentication_works?
    @authentication_works ||=
      begin
        EmailSettingsValidator.validate_pop3(
          host: SiteSetting.pop3_polling_host,
          port: SiteSetting.pop3_polling_port,
          ssl: SiteSetting.pop3_polling_ssl,
          username: SiteSetting.pop3_polling_username,
          password: SiteSetting.pop3_polling_password,
          openssl_verify: SiteSetting.pop3_polling_openssl_verify,
          oauth2: SiteSetting.pop3_polling_oauth2,
          oauth2_endpoint: SiteSetting.pop3_polling_oauth2_endpoint,
          oauth2_client_id: SiteSetting.pop3_polling_oauth2_clientid,
        )
      rescue *EmailSettingsExceptionHandler::EXPECTED_EXCEPTIONS => err
        false
      else
        true
      end
  end
end
