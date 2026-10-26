# frozen_string_literal: true

describe "Admin Theme Site Settings" do
  fab!(:current_user, :admin)
  fab!(:theme_1) { Fabricate(:theme, name: "Blue Steel") }
  fab!(:theme_2) { Fabricate(:theme, name: "Derelicte") }
  fab!(:theme_site_setting_1) do
    Fabricate(
      :theme_site_setting_with_service,
      theme: theme_1,
      name: "enable_welcome_banner",
      value: false,
    )
  end
  fab!(:theme_site_setting_2) do
    Fabricate(
      :theme_site_setting_with_service,
      theme: theme_2,
      name: "search_experience",
      value: "search_field",
    )
  end

  let(:theme_site_settings_page) { PageObjects::Pages::AdminThemeSiteSettings.new }

  before { sign_in(current_user) }

  it "shows theme setting defaults and the themes overriding them" do
    visit "/admin/config/customize/theme-site-settings"

    aggregate_failures("theme setting defaults") do
      expect(theme_site_settings_page).to have_setting_with_default("enable_welcome_banner")
      expect(theme_site_settings_page).to have_setting_with_default("search_experience")
    end

    aggregate_failures("theme override links and tooltips") do
      expect(theme_site_settings_page).to have_theme_overriding(
        "enable_welcome_banner",
        theme_1,
        "false",
      )
      expect(theme_site_settings_page).to have_theme_overriding(
        "search_experience",
        theme_2,
        "search_field",
      )
    end
  end

  describe "all site setting list" do
    fab!(:default_theme) { Theme.find_default }
    let(:site_settings_page) { PageObjects::Pages::AdminSiteSettings.new }

    it "shows warning and disabled state for themeable site settings" do
      site_settings_page.visit("enable_welcome_banner")

      expect(site_settings_page).to have_disabled_input("enable_welcome_banner")
      expect(site_settings_page).to have_theme_warning(
        "enable_welcome_banner",
        default_theme.name,
        default_theme.id,
      )
    end
  end
end
