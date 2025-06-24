# frozen_string_literal: true

describe "Admin Theme Site Settings", type: :system do
  fab!(:current_user) { Fabricate(:admin) }
  fab!(:theme_1) { Fabricate(:theme, name: "Blue Steel") }
  fab!(:theme_2) { Fabricate(:theme, name: "Derelicte") }
  fab!(:theme_site_setting_1) do
    Fabricate(:theme_site_setting, theme: theme_1, name: "enable_welcome_banner", value: false)
  end
  fab!(:theme_site_setting_2) do
    Fabricate(:theme_site_setting, theme: theme_2, name: "search_experience", value: "search_field")
  end

  let(:theme_site_settings_page) { PageObjects::Pages::AdminThemeSiteSettings.new }

  before { sign_in(current_user) }

  it "shows the themeable site settings and their name, description, and default value" do
    visit "/admin/config/theme-site-settings"
    expect(theme_site_settings_page).to have_setting_with_default("enable_welcome_banner")
    expect(theme_site_settings_page).to have_setting_with_default("search_experience")
  end

  it "shows links to each theme that overrides the default and overridden values" do
    visit "/admin/config/theme-site-settings"
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
