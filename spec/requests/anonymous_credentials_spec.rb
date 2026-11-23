# frozen_string_literal: true

RSpec.describe "Anonymous credential lifecycle", type: :request do
  fab!(:master) { Fabricate(:user, trust_level: TrustLevel[1]) }

  before do
    SiteSetting.allow_anonymous_mode = true
    SiteSetting.anonymous_posting_allowed_groups = Group::AUTO_GROUPS[:trust_level_1].to_s
  end

  let(:shadow) { AnonymousShadowCreator.get(master) }
  let(:shadow_key) { Fabricate(:readonly_user_api_key, user: shadow) }
  let(:key_headers) { { HTTP_USER_API_KEY: shadow_key.key } }

  def expect_shadow_key_to_authenticate
    get "/session/current.json", headers: key_headers
    expect(response.parsed_body.dig("current_user", "id")).to eq(shadow.id)
  end

  context "with an existing shadow session and API key" do
    let(:browser) { open_session }

    before do
      browser.sign_in(master)
      browser.post "/u/toggle-anon.json"
      expect(browser.response.status).to eq(200)
      browser.get "/session/current.json"
      expect(browser.response.parsed_body.dig("current_user", "id")).to eq(shadow.id)
      expect_shadow_key_to_authenticate
    end

    def expect_shadow_credentials_to_be_revoked
      browser.get "/session/current.json"
      expect(browser.response.status).to eq(404)

      reset!
      get "/session/current.json", headers: key_headers
      expect(response.status).to eq(403)
    end

    it "revokes both when the master resets their password" do
      email_token = Fabricate(:email_token, user: master, scope: EmailToken.scopes[:password_reset])
      put "/u/password-reset/#{email_token.token}.json", params: { password: "newpassword123" }
      expect(response.status).to eq(200)

      expect_shadow_credentials_to_be_revoked
    end

    it "revokes both when the master logs out of all devices" do
      sign_in(master)
      post "/u/#{master.username}/preferences/revoke-auth-token.json"
      expect(response.status).to eq(200)

      expect_shadow_credentials_to_be_revoked
    end

    it "revokes both when an admin logs the master out" do
      sign_in(Fabricate(:admin))
      post "/admin/users/#{master.id}/log_out.json"
      expect(response.status).to eq(200)

      expect_shadow_credentials_to_be_revoked
    end

    it "revokes both when the master deletes their account" do
      sign_in(master)
      delete "/u/#{master.username}.json"
      expect(response.status).to eq(200)

      expect_shadow_credentials_to_be_revoked
    end
  end

  it "revokes the whole identity on strict logout from anonymous mode" do
    SiteSetting.log_out_strict = true
    expect_shadow_key_to_authenticate
    master_token = UserAuthToken.generate!(user_id: master.id)
    previous_shadow = Fabricate(:user)
    AnonymousUser.create!(user: previous_shadow, master_user: master, active: false)
    previous_key = Fabricate(:user_api_key, user: previous_shadow)
    sign_in(master)
    post "/u/toggle-anon.json"
    expect(response.status).to eq(200)

    delete "/session/#{shadow.username}.json"
    expect(response.status).to eq(302)
    expect(UserAuthToken.exists?(master_token.id)).to eq(false)
    expect(previous_key.reload.revoked_at).to be_present

    get "/session/current.json"
    expect(response.status).to eq(404)
    get "/session/current.json", headers: key_headers
    expect(response.status).to eq(403)
  end

  it "does not let a shadow create another long-lived API credential" do
    SiteSetting.user_api_key_allowed_groups = Group::AUTO_GROUPS[:everyone].to_s
    sign_in(master)
    post "/u/toggle-anon.json"
    expect(response.status).to eq(200)

    post "/user-api-key.json",
         params: {
           scopes: "read,write",
           client_id: "x" * 32,
           application_name: "Shadow app",
           public_key: OpenSSL::PKey::RSA.new(2048).public_key.to_pem,
           nonce: SecureRandom.hex,
         }

    expect(response.status).to eq(403)
    expect(UserApiKey.where(user_id: master.shadow_user.id)).to be_empty
  end

  it "does not let a shadow restore a revoked API credential" do
    key = shadow_key
    key.update!(revoked_at: Time.zone.now)
    sign_in(master)
    post "/u/toggle-anon.json"
    expect(response.status).to eq(200)

    post "/user-api-key/undo-revoke.json", params: { id: key.id }

    expect(response.status).to eq(403)
    expect(key.reload.revoked_at).to be_present
  end

  it "refuses to exchange a legacy nested shadow for another shadow" do
    intermediate = shadow
    nested = Fabricate(:user)
    AnonymousUser.create!(user: nested, master_user: intermediate, active: true)
    master.destroy!
    session_token = UserAuthToken.generate!(user_id: nested.id)
    cookie = create_auth_cookie(token: session_token.unhashed_auth_token, user_id: nested.id)

    get "/session/current.json", headers: { "HTTP_COOKIE" => "_t=#{cookie}" }
    expect(response.parsed_body.dig("current_user", "id")).to eq(nested.id)
    expect {
      post "/u/toggle-anon.json", headers: { "HTTP_COOKIE" => "_t=#{cookie}" }
    }.not_to change { UserAuthToken.count }
    expect(response.status).to eq(403)
  end

  it "revokes a master session issued before revocation by exiting anonymous mode" do
    sign_in(master)
    post "/u/toggle-anon.json"
    expect(response.status).to eq(200)
    post "/u/toggle-anon.json"
    expect(response.status).to eq(200)
    get "/session/current.json"
    expect(response.parsed_body.dig("current_user", "id")).to eq(master.id)

    master.revoke_all_credentials!

    get "/session/current.json"
    expect(response.status).to eq(404)
  end

  it "revokes linked credentials even when anonymous mode has been disabled" do
    expect_shadow_key_to_authenticate
    master_token = UserAuthToken.generate!(user_id: master.id)
    SiteSetting.allow_anonymous_mode = false

    shadow.revoke_all_credentials!

    expect(UserAuthToken.exists?(master_token.id)).to eq(false)
    expect(shadow_key.reload.revoked_at).to be_present
    get "/session/current.json", headers: key_headers
    expect(response.status).to eq(403)
  end
end
