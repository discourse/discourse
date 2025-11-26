# frozen_string_literal: true

RSpec.describe Admin::Config::WelcomeBannerController do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)

  describe "#themes_with_setting" do
    fab!(:default_theme) { Fabricate(:theme, user_selectable: false) }
    fab!(:user_selectable_theme) { Fabricate(:theme, user_selectable: true) }
    fab!(:non_selectable_theme) { Fabricate(:theme, user_selectable: false) }
    fab!(:component) { Fabricate(:theme, component: true) }

    before { SiteSetting.default_theme_id = default_theme.id }

    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "returns user selectable themes and the default theme" do
        get "/admin/config/welcome-banner/themes-with-setting.json"

        expect(response.status).to eq(200)

        themes = response.parsed_body["themes"]
        theme_ids = themes.map { |t| t["id"] }

        expect(theme_ids).to include(default_theme.id)
        expect(theme_ids).to include(user_selectable_theme.id)
        expect(theme_ids).not_to include(non_selectable_theme.id)
      end

      it "excludes components" do
        get "/admin/config/welcome-banner/themes-with-setting.json"

        expect(response.status).to eq(200)

        theme_ids = response.parsed_body["themes"].map { |t| t["id"] }
        expect(theme_ids).not_to include(component.id)
      end

      it "returns enable_welcome_banner setting value when present" do
        Fabricate(
          :theme_site_setting,
          theme: user_selectable_theme,
          name: "enable_welcome_banner",
          value: true,
        )

        get "/admin/config/welcome-banner/themes-with-setting.json"

        expect(response.status).to eq(200)

        theme_data = response.parsed_body["themes"].find { |t| t["id"] == user_selectable_theme.id }
        expect(theme_data["enable_welcome_banner"]).to eq(true)
      end

      it "returns false for enable_welcome_banner when setting is not present" do
        get "/admin/config/welcome-banner/themes-with-setting.json"

        expect(response.status).to eq(200)

        theme_data = response.parsed_body["themes"].find { |t| t["id"] == user_selectable_theme.id }
        expect(theme_data["enable_welcome_banner"]).to eq(false)
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      it "denies access with a 403 response" do
        get "/admin/config/welcome-banner/themes-with-setting.json"
        expect(response.status).to eq(403)
      end
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      it "denies access with a 404 response" do
        get "/admin/config/welcome-banner/themes-with-setting.json"
        expect(response.status).to eq(404)
      end
    end
  end
end
