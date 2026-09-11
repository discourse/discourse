# frozen_string_literal: true

class AuthProviderCredentialsValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    return true if val == "f"
    missing_settings.empty?
  end

  def error_message
    I18n.t(
      "site_settings.errors.auth_provider_credentials_missing",
      settings: SiteSettings::LabelFormatter.setting_markers(missing_settings),
    )
  end

  private

  def missing_settings
    authenticator&.missing_settings.to_a
  end

  def authenticator
    @authenticator ||= Discourse.authenticators.find { it.enable_setting == @opts[:name] }
  end
end
