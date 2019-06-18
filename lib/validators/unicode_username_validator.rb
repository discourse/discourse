# frozen_string_literal: true

class UnicodeUsernameValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(value)
    @valid = SiteSetting.external_system_avatars_enabled || value == "f"
  end

  def error_message
    I18n.t("site_settings.errors.unicode_usernames_avatars") if !@valid
  end
end
