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

      it "returns discourse id configuration and stats" do
        get "/admin/config/login-and-authentication/discourse-id.json"

        expect(response.status).to eq(200)

        body = response.parsed_body
        expect(body["enabled"]).to eq(true)
        expect(body["configured"]).to eq(true)
        expect(body["client_id"]).to eq(DiscourseId.masked_client_id)
        expect(body["provider_url"]).to eq(DiscourseId.provider_url)
        expect(body["stats"]).to be_present
        expect(body["stats"]["total_users"]).to eq(0)
        expect(body["stats"]["signups_30_days"]).to eq(0)
        expect(body["stats"]["logins_30_days"]).to eq(0)
      end

      it "returns correct stats when users exist" do
        user1 = Fabricate(:user)
        user2 = Fabricate(:user)
        Fabricate(
          :user_associated_account,
          user: user1,
          provider_name: "discourse_id",
          provider_uid: SecureRandom.hex,
          created_at: 10.days.ago,
          last_used: 5.days.ago,
        )
        Fabricate(
          :user_associated_account,
          user: user2,
          provider_name: "discourse_id",
          provider_uid: SecureRandom.hex,
          created_at: 60.days.ago,
          last_used: 60.days.ago,
        )

        get "/admin/config/login-and-authentication/discourse-id.json"

        expect(response.status).to eq(200)

        body = response.parsed_body
        expect(body["stats"]["total_users"]).to eq(2)
        expect(body["stats"]["signups_30_days"]).to eq(1)
        expect(body["stats"]["logins_30_days"]).to eq(1)
      end

      it "returns configured as false when credentials are missing" do
        SiteSetting.discourse_id_client_id = ""

        get "/admin/config/login-and-authentication/discourse-id.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["configured"]).to eq(false)
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      it "denies access with a 403 response" do
        get "/admin/config/login-and-authentication/discourse-id.json"
        expect(response.status).to eq(403)
      end
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      it "denies access with a 404 response" do
        get "/admin/config/login-and-authentication/discourse-id.json"
        expect(response.status).to eq(404)
      end
    end

    context "when not logged in" do
      it "redirects to login" do
        get "/admin/config/login-and-authentication/discourse-id.json"
        expect(response.status).to eq(404)
      end
    end
  end

  describe "#regenerate_credentials" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "returns success when regeneration succeeds" do
        challenge_token = SecureRandom.hex
        new_secret = SecureRandom.hex

        stub_request(:post, "#{DiscourseId.provider_url}/challenge").to_return(
          status: 200,
          body: { domain: Discourse.current_hostname, token: challenge_token }.to_json,
        )

        stub_request(:post, "#{DiscourseId.provider_url}/regenerate").to_return(
          status: 200,
          body: { client_id:, client_secret: new_secret }.to_json,
        )

        post "/admin/config/login-and-authentication/discourse-id/regenerate.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["success"]).to eq("OK")
      end

      it "returns error when credentials are not configured" do
        SiteSetting.discourse_id_client_id = ""
        SiteSetting.discourse_id_client_secret = ""

        post "/admin/config/login-and-authentication/discourse-id/regenerate.json"

        expect(response.status).to eq(422)
        expect(response.parsed_body["error"]).to be_present
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      it "denies access with a 403 response" do
        post "/admin/config/login-and-authentication/discourse-id/regenerate.json"
        expect(response.status).to eq(403)
      end
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      it "denies access with a 404 response" do
        post "/admin/config/login-and-authentication/discourse-id/regenerate.json"
        expect(response.status).to eq(404)
      end
    end
  end

  describe "#update_settings" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "updates the enabled setting to true" do
        SiteSetting.enable_discourse_id = false

        put "/admin/config/login-and-authentication/discourse-id/settings.json",
            params: {
              enabled: true,
            }

        expect(response.status).to eq(200)
        expect(SiteSetting.enable_discourse_id).to eq(true)
      end

      it "updates the enabled setting to false" do
        SiteSetting.enable_discourse_id = true

        put "/admin/config/login-and-authentication/discourse-id/settings.json",
            params: {
              enabled: false,
            }

        expect(response.status).to eq(200)
        expect(SiteSetting.enable_discourse_id).to eq(false)
      end

      it "returns success even without params" do
        put "/admin/config/login-and-authentication/discourse-id/settings.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["success"]).to eq("OK")
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      it "denies access with a 403 response" do
        put "/admin/config/login-and-authentication/discourse-id/settings.json",
            params: {
              enabled: false,
            }

        expect(response.status).to eq(403)
        expect(SiteSetting.enable_discourse_id).to eq(true)
      end
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      it "denies access with a 404 response" do
        put "/admin/config/login-and-authentication/discourse-id/settings.json",
            params: {
              enabled: false,
            }

        expect(response.status).to eq(404)
        expect(SiteSetting.enable_discourse_id).to eq(true)
      end
    end
  end
end
