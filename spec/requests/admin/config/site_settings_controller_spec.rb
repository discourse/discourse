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

      it "returns 400 when no filter_area is invalid" do
        get "/admin/config/site_settings.json", params: { filter_area: "invalid area" }
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

      it "returns site settings by area" do
        get "/admin/config/site_settings.json", params: { filter_area: "flags" }
        expect(response.status).to eq(200)
        expect(response.parsed_body["site_settings"].map { |s| s["setting"] }).to match_array(
          %w[
            allow_tl0_and_anonymous_users_to_flag_illegal_content
            email_address_to_report_illegal_content
            silence_new_user_sensitivity
            num_users_to_silence_new_user
            flag_sockpuppets
            num_flaggers_to_close_topic
            auto_respond_to_flag_actions
            high_trust_flaggers_auto_hide_posts
            max_flags_per_day
            tl2_additional_flags_per_day_multiplier
            tl3_additional_flags_per_day_multiplier
            tl4_additional_flags_per_day_multiplier
          ],
        )
      end
    end
  end
end
