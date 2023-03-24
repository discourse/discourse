# frozen_string_literal: true

RSpec.describe EnableNewNotificationsMenuValidator do
  it "does not allow `enable_new_notifications_menu` site settings to be enabled when `navigation_menu` site settings is not set to `legacy`" do
    SiteSetting.navigation_menu = "sidebar"

    expect { SiteSetting.enable_new_notifications_menu = true }.to raise_error(
      Discourse::InvalidParameters,
      /#{I18n.t("site_settings.errors.enable_new_notifications_menu_not_legacy_navigation_menu")}/,
    )
  end

  it "allows `enable_new_notifications_menu` site settings to be enabled when `navigation_menu` site settings is set to `legacy`" do
    SiteSetting.navigation_menu = "legacy"

    expect { SiteSetting.enable_new_notifications_menu = true }.to_not raise_error
  end
end
