# frozen_string_literal: true

class PatreonLoginEnabledValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    return true if val == "f"
    return false if SiteSetting.patreon_creator_discourse_username.blank?
    true
  end

  def error_message
    I18n.t("site_settings.errors.patreon_creator_username_not_set")
  end
end
