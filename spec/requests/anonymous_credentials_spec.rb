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

  context "with independent logins for the same master" do
    let(:switching_browser) { open_session }
    let(:other_browser) { open_session }

    before do
      SiteSetting.log_out_strict = false
      switching_browser.sign_in(master)
      other_browser.sign_in(master)
    end

    def expect_signed_in_as(browser, user)
      browser.get "/session/current.json"
      expect(browser.response.parsed_body.dig("current_user", "id")).to eq(user.id)
    end

    def switch_to(browser, user)
      browser.post "/u/toggle-anon.json"
      expect(browser.response.status).to eq(200)
      expect_signed_in_as(browser, user)
    end

    def current_device_id(browser)
      browser.get "/u/#{master.username}.json"
      devices = browser.response.parsed_body.fetch("user").fetch("user_auth_tokens")
      devices.select { |device| device.fetch("is_active") }.sole.fetch("id")
    end

    it "rejects another user's request to revoke a switched device by ID" do
      device_id = current_device_id(switching_browser)
      switch_to(switching_browser, shadow)
      outsider = sign_in(Fabricate(:user))

      post "/u/#{outsider.username}/preferences/revoke-auth-token.json",
           params: {
             token_id: device_id,
           }
      expect(response.status).to eq(400)
      expect_signed_in_as(switching_browser, shadow)
    end

    it "protects the current device's original ID across switches and cookie rotation" do
      device_id = current_device_id(switching_browser)
      switch_to(switching_browser, shadow)
      switch_to(switching_browser, master)
      cookie = switching_browser.cookies["_t"]
      freeze_time (UserAuthToken::ROTATE_TIME + 1.minute).from_now
      expect(current_device_id(switching_browser)).to eq(device_id)
      expect(switching_browser.cookies["_t"]).not_to eq(cookie)

      switching_browser.post "/u/#{master.username}/preferences/revoke-auth-token.json",
                             params: {
                               token_id: device_id,
                             }
      expect(switching_browser.response.status).to eq(400)
      expect_signed_in_as(switching_browser, master)
    end

    def register_push(browser, user, device)
      subscription = {
        endpoint: "https://fcm.googleapis.com/fcm/send/#{device}",
        keys: {
          p256dh: "p256dh",
          auth: "auth",
        },
      }
      browser.post "/push_notifications/subscribe.json", params: { subscription: }
      expect(browser.response.status).to eq(200)
      user.push_subscriptions.find_by!(data: subscription.to_json)
    end

    it "moves both personas' subscriptions across exchanges and revokes only the selected device" do
      sign_in(master)
      device_id = current_device_id(switching_browser)
      master_push = register_push(switching_browser, master, "switching")
      other_master_push = register_push(other_browser, master, "other")

      switch_to(switching_browser, shadow)
      shadow_push = register_push(switching_browser, shadow, "switching")
      switch_to(other_browser, shadow)
      other_shadow_push = register_push(other_browser, shadow, "other")
      switch_to(switching_browser, master)
      switch_to(switching_browser, shadow)

      successor = AnonymousModeSession.find(device_id).user_auth_token
      expect(
        PushSubscription.where(user_auth_token: successor).pluck(:id, :user_id),
      ).to contain_exactly([master_push.id, master.id], [shadow_push.id, shadow.id])
      get "/u/#{master.username}.json"
      expect(response.parsed_body.dig("user", "user_auth_tokens")).to include(
        a_hash_including("id" => device_id, "is_active" => false),
      )

      post "/u/#{master.username}/preferences/revoke-auth-token.json",
           params: {
             token_id: device_id,
           }
      expect(response.status).to eq(200)
      expect(PushSubscription.where(user: [master, shadow])).to contain_exactly(
        other_master_push,
        other_shadow_push,
      )
      switching_browser.get "/session/current.json"
      expect(switching_browser.response.status).to eq(404)
      expect_signed_in_as(other_browser, shadow)
      get "/session/current.json"
      expect(response.parsed_body.dig("current_user", "id")).to eq(master.id)
    end

    it "revokes both personas' subscriptions on ordinary logout without an endpoint" do
      register_push(switching_browser, master, "switching")
      other_push = register_push(other_browser, master, "other")
      switch_to(switching_browser, shadow)
      register_push(switching_browser, shadow, "switching")

      switching_browser.delete "/session/#{shadow.username}.json"

      expect(switching_browser.response.status).to eq(302)
      expect(PushSubscription.where(user: [master, shadow])).to contain_exactly(other_push)
      expect_signed_in_as(other_browser, master)
    end

    def expect_stale_logout_to_revoke_only_its_login
      cookie = switching_browser.cookies["_t"]
      original_cookie = { "HTTP_COOKIE" => "_t=#{Rack::Utils.escape(cookie)}" }
      register_push(switching_browser, master, "switching")
      other_push = register_push(other_browser, master, "other")
      switch_to(switching_browser, shadow)
      register_push(switching_browser, shadow, "switching")
      switch_to(switching_browser, master)
      switch_to(switching_browser, shadow)
      freeze_time 2.minutes.from_now
      # Advancing Rails time does not expire the presented cookie's real Redis grace marker.
      token = decrypt_auth_cookie(cookie).fetch(:token)
      Discourse.redis.del("replaced_browser_cookie:#{UserAuthToken.hash_token(token)}")

      get "/session/current.json", headers: original_cookie
      expect(response.status).to eq(404)
      expect_signed_in_as(switching_browser, shadow)

      reset!
      delete "/session/#{master.username}.json", headers: original_cookie
      expect(response.status).to eq(302)
      expect(PushSubscription.where(user: [master, shadow])).to contain_exactly(other_push)

      switching_browser.get "/session/current.json"
      expect(switching_browser.response.status).to eq(404)
      expect_signed_in_as(other_browser, master)
    end

    it "honors ordinary logout with the original cookie after multiple switches and the grace period" do
      expect_stale_logout_to_revoke_only_its_login
    end

    it "limits strict logout to one login when only a stale cookie is presented" do
      SiteSetting.log_out_strict = true
      expect_stale_logout_to_revoke_only_its_login
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

    master.revoke_family_sessions!

    get "/session/current.json"
    expect(response.status).to eq(404)
  end

  it "revokes linked credentials even when anonymous mode has been disabled" do
    expect_shadow_key_to_authenticate
    master_token = UserAuthToken.generate!(user_id: master.id)
    SiteSetting.allow_anonymous_mode = false

    shadow.revoke_family_sessions!

    expect(UserAuthToken.exists?(master_token.id)).to eq(false)
    expect(shadow_key.reload.revoked_at).to be_present
    get "/session/current.json", headers: key_headers
    expect(response.status).to eq(403)
  end
end
