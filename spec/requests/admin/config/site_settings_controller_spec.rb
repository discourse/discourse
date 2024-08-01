# frozen_string_literal: true

RSpec.describe Admin::SiteSettingsController do
  fab!(:admin)
  fab!(:user)

  describe "#index" do
    context "when not logged in" do
      it "returns 404" do
        get "/admin/config/site_settings.json"
        expect(response.status).to eq(404)
      end
    end

    context "when not admin" do
      before { sign_in(user) }

      it "returns 404" do
        get "/admin/config/site_settings.json"
        expect(response.status).to eq(404)
      end
    end

    context "when logged in as admin" do
      before { sign_in(admin) }

      it "returns 400 when no filter_names are provided" do
        get "/admin/config/site_settings.json"
        expect(response.status).to eq(400)
      end

      it "includes only certain allowed hidden settings" do
        get "/admin/config/site_settings.json",
            params: {
              filter_names: [
                Admin::Config::SiteSettingsController::ADMIN_CONFIG_AREA_ALLOWLISTED_HIDDEN_SETTINGS,
              ],
            }
        expect(
          response.parsed_body["site_settings"].find do |s|
            s["setting"] ==
              Admin::Config::SiteSettingsController::ADMIN_CONFIG_AREA_ALLOWLISTED_HIDDEN_SETTINGS.first.to_s
          end,
        ).to be_present
        get "/admin/config/site_settings.json", params: { filter_names: ["set_locale_from_cookie"] }
        expect(
          response.parsed_body["site_settings"].find do |s|
            s["setting"] == "set_locale_from_cookie"
          end,
        ).to be_nil
      end

      it "returns site settings by exact name" do
        get "/admin/config/site_settings.json",
            params: {
              filter_names: %w[site_description enforce_second_factor],
            }
        expect(response.status).to eq(200)
        expect(response.parsed_body["site_settings"].map { |s| s["setting"] }).to match_array(
          %w[site_description enforce_second_factor],
        )
      end
    end
  end
end
