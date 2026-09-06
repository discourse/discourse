# frozen_string_literal: true

class EnableLocalLoginsViaCodeValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    return true if val == "f"

    @error_message_key =
      if !SiteSetting.enable_local_logins
        "site_settings.errors.enable_local_logins_disabled"
      elsif !SiteSetting.enable_local_logins_via_email
        "site_settings.errors.enable_local_logins_via_email_disabled"
      elsif SiteSetting.enable_discourse_connect
        "site_settings.errors.discourse_connect_enabled"
      end

    @error_message_key.nil?
  end

  def error_message
    I18n.t(@error_message_key) if @error_message_key
  end
end
