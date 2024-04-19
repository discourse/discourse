# frozen_string_literal: true

class LinkedinOidcCredentialsValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    return true if val == "f"
    return false if credentials_missing?
    true
  end

  def error_message
    I18n.t("site_settings.errors.linkedin_oidc_credentials") if credentials_missing?
  end

  private

  def credentials_missing?
    SiteSetting.linkedin_oidc_client_id.blank? || SiteSetting.linkedin_oidc_client_secret.blank?
  end
end
