# frozen_string_literal: true

class EnableNewNotificationsMenuValidator
  def initialize(opts = {})
  end

  def valid_value?(value)
    return true if value == "f"
    SiteSetting.navigation_menu == "legacy"
  end

  def error_message
    I18n.t("site_settings.errors.enable_new_notifications_menu_not_legacy_navigation_menu")
  end
end
