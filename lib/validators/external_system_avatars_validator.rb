# frozen_string_literal: true

class ExternalSystemAvatarsValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(value)
    @valid = value == "t" || !SiteSetting.unicode_usernames
  end

  def error_message
    I18n.t("site_settings.errors.unicode_usernames_avatars") if !@valid
  end
end
