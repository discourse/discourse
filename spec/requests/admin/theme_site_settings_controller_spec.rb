# frozen_string_literal: true

RSpec.describe Admin::Config::ThemeSiteSettingsController do
  fab!(:admin)
  fab!(:theme_1) { Fabricate(:theme) }
  fab!(:theme_2) { Fabricate(:theme) }
  fab!(:theme_3) { Fabricate(:theme) }

  before do
    sign_in(admin)
    Fabricate(:theme_site_setting, theme: theme_1, name: "search_experience", value: "search_field")
    Fabricate(:theme_site_setting, theme: theme_2, name: "enable_welcome_banner", value: false)
  end

  describe "#index" do
    it "gets all theme site settings and the themes which have overridden values for these settings" do
      get "/admin/config/theme-site-settings.json"

      expect(response.status).to eq(200)
      json = response.parsed_body

      expect(json["themeable_site_settings"]).to include(
        "search_experience",
        "enable_welcome_banner",
      )

      search_setting =
        json["themes_with_site_setting_overrides"]["search_experience"].deep_symbolize_keys
      expect(search_setting[:setting]).to eq("search_experience")
      expect(search_setting[:default]).to eq("search_icon")
      expect(search_setting[:description]).to eq(I18n.t("site_settings.search_experience"))
      expect(search_setting[:type]).to eq("enum")
      expect(search_setting[:themes].find { |t| t[:theme_id] == theme_1.id }).to include(
        theme_name: theme_1.name,
        theme_id: theme_1.id,
        value: "search_field",
      )

      welcome_banner_setting =
        json["themes_with_site_setting_overrides"]["enable_welcome_banner"].deep_symbolize_keys
      expect(welcome_banner_setting[:setting]).to eq("enable_welcome_banner")
      expect(welcome_banner_setting[:default]).to eq("true")
      expect(welcome_banner_setting[:description]).to eq(
        I18n.t("site_settings.enable_welcome_banner"),
      )
      expect(welcome_banner_setting[:type]).to eq("bool")
      expect(welcome_banner_setting[:themes].find { |t| t[:theme_id] == theme_2.id }).to include(
        theme_name: theme_2.name,
        theme_id: theme_2.id,
        value: false,
      )
    end
  end
end
