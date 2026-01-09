# frozen_string_literal: true

RSpec.describe Admin::Config::DiscourseIdController do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)

  let(:client_id) { SecureRandom.hex }
  let(:client_secret) { SecureRandom.hex }

  before do
    SiteSetting.discourse_id_client_id = client_id
    SiteSetting.discourse_id_client_secret = client_secret
    SiteSetting.enable_discourse_id = true
  end

  describe "#show" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "returns configuration and stats" do
        recent_user = Fabricate(:user)
        old_user = Fabricate(:user)
        Fabricate(
          :user_associated_account,
          user: recent_user,
          provider_name: "discourse_id",
          provider_uid: SecureRandom.hex,
          created_at: 10.days.ago,
          last_used: 5.days.ago,
        )
        Fabricate(
          :user_associated_account,
          user: old_user,
          provider_name: "discourse_id",
          provider_uid: SecureRandom.hex,
          created_at: 60.days.ago,
          last_used: 60.days.ago,
        )

        get "/admin/config/login-and-authentication/discourse-id.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body).to include(
          "enabled" => true,
          "configured" => true,
          "stats" => {
            "total_users" => 2,
            "signups_30_days" => 1,
            "logins_30_days" => 1,
          },
        )
      end

      it "returns configured as false when credentials are missing" do
        SiteSetting.discourse_id_client_id = ""

        get "/admin/config/login-and-authentication/discourse-id.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["configured"]).to eq(false)
      end
    end

    it "is admin only" do
      get "/admin/config/login-and-authentication/discourse-id.json"
      expect(response.status).to eq(404)

      sign_in(user)
      get "/admin/config/login-and-authentication/discourse-id.json"
      expect(response.status).to eq(404)

      sign_in(moderator)
      get "/admin/config/login-and-authentication/discourse-id.json"
      expect(response.status).to eq(403)
    end
  end

  describe "#regenerate_credentials" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "regenerates credentials successfully" do
        stub_request(:post, "#{DiscourseId.provider_url}/challenge").to_return(
          status: 200,
          body: { domain: Discourse.current_hostname, token: "token" }.to_json,
        )
        stub_request(:post, "#{DiscourseId.provider_url}/regenerate").to_return(
          status: 200,
          body: { client_id:, client_secret: "new_secret" }.to_json,
        )

        post "/admin/config/login-and-authentication/discourse-id/regenerate.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["success"]).to eq("OK")
      end

      it "returns error when credentials are not configured" do
        SiteSetting.discourse_id_client_id = ""

        post "/admin/config/login-and-authentication/discourse-id/regenerate.json"

        expect(response.status).to eq(422)
        expect(response.parsed_body["error"]).to be_present
      end
    end

    it "is admin only" do
      post "/admin/config/login-and-authentication/discourse-id/regenerate.json"
      expect(response.status).to eq(404)

      sign_in(moderator)
      post "/admin/config/login-and-authentication/discourse-id/regenerate.json"
      expect(response.status).to eq(403)
    end
  end

  describe "#update_settings" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "updates the enabled setting" do
        SiteSetting.enable_discourse_id = false

        put "/admin/config/login-and-authentication/discourse-id/settings.json",
            params: {
              enabled: true,
            }

        expect(response.status).to eq(200)
        expect(SiteSetting.enable_discourse_id).to eq(true)
      end
    end

    it "is admin only" do
      put "/admin/config/login-and-authentication/discourse-id/settings.json",
          params: {
            enabled: false,
          }
      expect(response.status).to eq(404)
      expect(SiteSetting.enable_discourse_id).to eq(true)

      sign_in(moderator)
      put "/admin/config/login-and-authentication/discourse-id/settings.json",
          params: {
            enabled: false,
          }
      expect(response.status).to eq(403)
      expect(SiteSetting.enable_discourse_id).to eq(true)
    end
  end
end
