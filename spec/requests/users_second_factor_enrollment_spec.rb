# frozen_string_literal: true

require "rotp"

RSpec.describe UsersController do
  fab!(:user) { Fabricate(:user, password: nil, created_at: 1.day.ago) }

  describe "second factor management on a mixed login site" do
    def sign_in_with_oauth_token
      sign_in(user)
      user.user_auth_tokens.last.update!(authenticated_with_oauth: true)
    end

    it "offers local password confirmation without using the account age as proof" do
      password = "a separate local password"
      user.update!(password: password, created_at: 1.minute.ago)
      sign_in_with_oauth_token

      post "/u/second_factors.json"
      expect(response.parsed_body).to eq("success" => "OK", "unconfirmed_session" => true)

      post "/u/create_second_factor_totp.json"
      expect(response).to have_http_status(:forbidden)

      post "/u/confirm-session.json", params: { password: password }
      expect(response.parsed_body["success"]).to eq("OK")

      post "/u/create_second_factor_totp.json"
      expect(response).to have_http_status(:ok)
    end

    it "offers local confirmation with an enabled passkey in a supported browser" do
      SiteSetting.enable_passkeys = true
      Fabricate(:passkey_with_random_credential, user: user)
      sign_in_with_oauth_token

      post "/u/second_factors.json", params: { webauthn_supported: true }
      expect(response.parsed_body).to eq("success" => "OK", "unconfirmed_session" => true)

      post "/u/second_factors.json", params: { webauthn_supported: false }
      expect(response.parsed_body).to eq("success" => "OK", "external_login_required" => true)
    end

    it "requires provider sign-in for a new OAuth account without usable local credentials" do
      SiteSetting.enable_passkeys = true
      user.update!(created_at: 1.minute.ago)
      Fabricate(:passkey_with_random_credential, user: user, enabled: false)
      sign_in_with_oauth_token

      post "/u/second_factors.json", params: { webauthn_supported: true }
      expect(response.parsed_body).to eq("success" => "OK", "external_login_required" => true)

      post "/u/create_second_factor_totp.json"
      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body["error_type"]).to eq("second_factor_external_login_required")
    end
  end

  describe "second factor management with external authentication" do
    before do
      SiteSetting.discourse_connect_url = "https://example.com/sso"
      SiteSetting.discourse_connect_secret = "external-login-test"
      SiteSetting.enable_discourse_connect = true
    end

    def sign_in_with_discourse_connect
      get "/session/sso"
      sso =
        DiscourseConnectBase.parse(
          URI(response.location).query,
          SiteSetting.discourse_connect_secret,
        )
      sso.external_id = "external-user"
      sso.email = user.email
      sso.username = user.username
      get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload)
      expect(response).to have_http_status(:found)
    end

    it "enrolls a TOTP after a completed external login without confirming a local credential" do
      sign_in_with_discourse_connect

      post "/u/second_factors.json"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["totps"]).to eq([])

      post "/u/create_second_factor_totp.json"
      expect(response).to have_http_status(:ok)
      key = response.parsed_body.fetch("key").delete(" ")

      post "/u/enable_second_factor_totp.json",
           params: {
             name: "Authenticator",
             second_factor_token: ROTP::TOTP.new(key).now,
           }
      expect(response).to have_http_status(:ok)
      expect(user.totps.pluck(:name)).to eq(["Authenticator"])
    end

    it "manages native factors and regenerates backup codes after the external login" do
      sign_in_with_discourse_connect
      security_key = Fabricate(:user_security_key_with_random_credential, user: user)

      put "/u/security_key.json", params: { id: security_key.id, name: "Updated key" }
      expect(response).to have_http_status(:ok)
      expect(security_key.reload.name).to eq("Updated key")

      put "/u/second_factors_backup.json"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["backup_codes"]).to be_present
    end

    it "requires a new provider sign-in when the grant expires" do
      freeze_time
      sign_in_with_discourse_connect
      freeze_time 6.minutes.from_now

      post "/u/second_factors.json"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["external_login_required"]).to eq(true)

      post "/u/create_second_factor_totp.json"
      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body["error_type"]).to eq("second_factor_external_login_required")
    end

    it "does not carry the grant over to a different session for the same user" do
      sign_in_with_discourse_connect
      sign_in(user)

      post "/u/create_second_factor_totp.json"
      expect(response).to have_http_status(:forbidden)
    end

    it "does not grant enrollment access to an API request even when the browser holds the grant" do
      sign_in_with_discourse_connect
      api_key = Fabricate(:api_key, user: user)

      post "/u/create_second_factor_totp.json",
           headers: {
             "Api-Key" => api_key.key,
             "Api-Username" => user.username,
           }

      expect(response).to have_http_status(:forbidden)
    end

    it "does not confirm the general-purpose trusted session or allow first-factor key changes" do
      SiteSetting.enable_passkeys = true
      passkey = Fabricate(:passkey_with_random_credential, user: user)
      sign_in_with_discourse_connect

      get "/u/trusted-session.json"
      expect(response.parsed_body["success"]).to be_nil

      put "/u/security_key.json", params: { id: passkey.id, disable: "true" }
      expect(response).to have_http_status(:bad_request)
      expect(passkey.reload.enabled).to eq(true)

      delete "/u/delete_passkey/#{passkey.id}.json"
      expect(response).to have_http_status(:not_found)
    end
  end
end
