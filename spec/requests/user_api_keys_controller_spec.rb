# frozen_string_literal: true

RSpec.describe UserApiKeysController do
  let(:private_key) { OpenSSL::PKey::RSA.new(2048) }
  let(:public_key) { private_key.public_key.to_pem }

  let(:args) do
    {
      scopes: "read",
      client_id: "x" * 32,
      auth_redirect: "http://over.the/rainbow",
      application_name: "foo",
      public_key:,
      nonce: SecureRandom.hex,
    }
  end

  let(:otp_args) do
    { auth_redirect: "http://somewhere.over.the/rainbow", application_name: "foo", public_key: }
  end

  def decrypt_payload(encrypted, padding: nil)
    if padding == "oaep"
      private_key.private_decrypt(encrypted, OpenSSL::PKey::RSA::PKCS1_OAEP_PADDING)
    else
      private_key.private_decrypt(encrypted)
    end
  end

  def extract_payload_from_redirect(response, key: "payload")
    uri = URI.parse(response.redirect_url)
    payload = uri.query.split("#{key}=")[1]
    Base64.decode64(CGI.unescape(payload))
  end

  describe "#new" do
    it "supports a head request cleanly" do
      head "/user-api-key/new"
      expect(response.status).to eq(200)
      expect(response.headers["Auth-Api-Version"]).to eq("4")
    end

    it "includes padding parameter in the form only when provided" do
      sign_in(Fabricate(:user, refresh_auto_groups: true))

      get "/user-api-key/new", params: args
      expect(response.body).not_to include('name="padding"')

      get "/user-api-key/new", params: args.merge(padding: "oaep")
      expect(response.body).to include('name="padding"', 'value="oaep"')
    end
  end

  describe "#create" do
    it "does not allow anon" do
      post "/user-api-key.json", params: args
      expect(response.status).to eq(403)
    end

    it "refuses to redirect to disallowed place" do
      sign_in(Fabricate(:user))
      post "/user-api-key.json", params: args
      expect(response.status).to eq(403)
    end

    it "allows tokens for staff without meeting TL requirement" do
      SiteSetting.user_api_key_allowed_groups = Group::AUTO_GROUPS[:trust_level_2]
      SiteSetting.allowed_user_api_auth_redirects = args[:auth_redirect]
      sign_in(Fabricate(:user, trust_level: TrustLevel[1], moderator: true))

      post "/user-api-key.json", params: args
      expect(response.status).to eq(302)
    end

    it "does not create token unless TL requirement is met" do
      SiteSetting.user_api_key_allowed_groups = Group::AUTO_GROUPS[:trust_level_2]
      SiteSetting.allowed_user_api_auth_redirects = args[:auth_redirect]
      sign_in(Fabricate(:user, trust_level: TrustLevel[1]))

      post "/user-api-key.json", params: args
      expect(response.status).to eq(403)
    end

    it "denies access if requesting more scopes than allowed" do
      SiteSetting.user_api_key_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
      SiteSetting.allowed_user_api_auth_redirects = args[:auth_redirect]
      SiteSetting.allow_user_api_key_scopes = "write"
      sign_in(Fabricate(:user, trust_level: TrustLevel[0]))

      post "/user-api-key.json", params: args
      expect(response.status).to eq(403)
    end

    it "does not return push access if push URL not configured" do
      SiteSetting.user_api_key_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
      SiteSetting.allowed_user_api_auth_redirects = args[:auth_redirect]
      user = Fabricate(:user, trust_level: TrustLevel[0])
      sign_in(user)

      post "/user-api-key.json",
           params: args.merge(scopes: "push,read", push_url: "https://push.it/here")
      expect(response.status).to eq(302)

      parsed = JSON.parse(decrypt_payload(extract_payload_from_redirect(response)))
      expect(parsed["push"]).to eq(false)
      expect(user.user_api_keys.first.scopes.map(&:name)).to include("push")
    end

    it "redirects with valid encrypted token" do
      SiteSetting.user_api_key_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
      SiteSetting.allowed_user_api_auth_redirects = args[:auth_redirect]
      SiteSetting.allowed_user_api_push_urls = "https://push.it/here"
      user = Fabricate(:user, trust_level: TrustLevel[0])
      sign_in(user)

      post "/user-api-key.json",
           params:
             args.merge(
               scopes: "push,notifications,message_bus,session_info,one_time_password",
               push_url: "https://push.it/here",
             )
      expect(response.status).to eq(302)

      parsed = JSON.parse(decrypt_payload(extract_payload_from_redirect(response)))
      expect(parsed["nonce"]).to eq(args[:nonce])
      expect(parsed["push"]).to eq(true)
      expect(parsed["api"]).to eq(4)

      api_key = UserApiKey.with_key(parsed["key"]).first
      expect(api_key.user_id).to eq(user.id)
      expect(api_key.scopes.map(&:name).sort).to eq(
        %w[message_bus notifications one_time_password push session_info],
      )
    end

    it "returns payload without redirect when auth_redirect not provided" do
      SiteSetting.user_api_key_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
      user = Fabricate(:user, trust_level: TrustLevel[0])
      sign_in(user)

      post "/user-api-key.json", params: args.except(:auth_redirect)
      expect(response.status).to eq(200)

      encrypted = Base64.decode64(response.parsed_body["payload"])
      parsed = JSON.parse(decrypt_payload(encrypted))
      expect(UserApiKey.with_key(parsed["key"]).first.user_id).to eq(user.id)
    end

    it "encrypts payload with OAEP padding when requested" do
      SiteSetting.user_api_key_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
      user = Fabricate(:user, trust_level: TrustLevel[0])
      sign_in(user)

      post "/user-api-key.json", params: args.except(:auth_redirect).merge(padding: "oaep")
      expect(response.status).to eq(200)

      encrypted = Base64.decode64(response.parsed_body["payload"])
      parsed = JSON.parse(decrypt_payload(encrypted, padding: "oaep"))
      expect(UserApiKey.with_key(parsed["key"]).first.user_id).to eq(user.id)
    end

    it "rejects OAEP requests when payload exceeds maximum size for the key" do
      SiteSetting.user_api_key_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
      sign_in(Fabricate(:user, trust_level: TrustLevel[0]))

      post "/user-api-key.json",
           params: args.except(:auth_redirect).merge(padding: "oaep", nonce: "x" * 150)
      expect(response.status).to eq(400)
      expect(response.parsed_body["errors"].first).to include("Payload too large for OAEP")
    end

    it "allows redirect to wildcard urls" do
      SiteSetting.allowed_user_api_auth_redirects = args[:auth_redirect] + "/*"
      sign_in(Fabricate(:user, refresh_auto_groups: true))

      post "/user-api-key.json", params: args.merge(auth_redirect: args[:auth_redirect] + "/foo")
      expect(response.status).to eq(302)
    end

    it "preserves query params in auth_redirect" do
      SiteSetting.user_api_key_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
      SiteSetting.allowed_user_api_auth_redirects = args[:auth_redirect] + "/*"
      sign_in(Fabricate(:user, trust_level: TrustLevel[0]))

      post "/user-api-key.json", params: args.merge(auth_redirect: args[:auth_redirect] + "/?p=1")
      expect(response.redirect_url).to include("?p=1")
    end

    context "with a registered client" do
      let!(:user) { Fabricate(:user, trust_level: TrustLevel[1]) }
      let!(:client) do
        Fabricate(
          :user_api_key_client,
          client_id: args[:client_id],
          application_name: args[:application_name],
          public_key: public_key,
          auth_redirect: args[:auth_redirect],
          scopes: "read",
        )
      end

      before { sign_in(user) }

      it "does not require allowed_user_api_auth_redirects site setting" do
        post "/user-api-key.json", params: args
        expect(response.status).to eq(302)
      end

      it "does not require application_name or public_key params" do
        post "/user-api-key.json", params: args.except(:application_name, :public_key)
        expect(response.status).to eq(302)
      end

      it "rejects scopes not allowed by client" do
        post "/user-api-key.json", params: args.merge(scopes: "write")
        expect(response.status).to eq(403)
      end
    end
  end

  describe "#revoke" do
    it "allows revoking via API key header without id" do
      key = Fabricate(:readonly_user_api_key)

      post "/user-api-key/revoke.json", headers: { HTTP_USER_API_KEY: key.key }
      expect(response.status).to eq(200)
      expect(key.reload.revoked_at).not_to be_nil
    end

    it "allows revoking own key by id" do
      key = Fabricate(:readonly_user_api_key)

      post "/user-api-key/revoke.json",
           params: {
             id: key.id,
           },
           headers: {
             HTTP_USER_API_KEY: key.key,
           }
      expect(response.status).to eq(200)
      expect(key.reload.revoked_at).not_to be_nil
    end

    it "does not allow revoking another user's key via API key" do
      key1 = Fabricate(:readonly_user_api_key)
      key2 = Fabricate(:readonly_user_api_key)

      post "/user-api-key/revoke.json",
           params: {
             id: key2.id,
           },
           headers: {
             HTTP_USER_API_KEY: key1.key,
           }
      expect(response.status).to eq(403)
    end

    it "does not allow revoking another user's key via session" do
      key = Fabricate(:readonly_user_api_key)
      sign_in(Fabricate(:user))

      post "/user-api-key/revoke.json", params: { id: key.id }
      expect(response.status).to eq(403)
      expect(key.reload.revoked_at).to be_nil
    end
  end

  describe "#otp" do
    it "includes padding parameter in the form only when provided" do
      SiteSetting.allowed_user_api_auth_redirects = otp_args[:auth_redirect]
      sign_in(Fabricate(:user, refresh_auto_groups: true))

      get "/user-api-key/otp", params: otp_args
      expect(response.body).not_to include('name="padding"')

      get "/user-api-key/otp", params: otp_args.merge(padding: "oaep")
      expect(response.body).to include('name="padding"', 'value="oaep"')
    end
  end

  describe "#create_otp" do
    it "does not allow anon" do
      post "/user-api-key/otp", params: otp_args
      expect(response.status).to eq(403)
    end

    it "refuses to redirect to disallowed place" do
      sign_in(Fabricate(:user))
      post "/user-api-key/otp", params: otp_args
      expect(response.status).to eq(403)
    end

    it "allows OTP for staff without meeting TL requirement" do
      SiteSetting.user_api_key_allowed_groups = Group::AUTO_GROUPS[:trust_level_2]
      SiteSetting.allowed_user_api_auth_redirects = otp_args[:auth_redirect]
      sign_in(Fabricate(:user, trust_level: TrustLevel[1], moderator: true))

      post "/user-api-key/otp", params: otp_args
      expect(response.status).to eq(302)
    end

    it "does not allow OTP unless TL requirement is met" do
      SiteSetting.user_api_key_allowed_groups = Group::AUTO_GROUPS[:trust_level_2]
      SiteSetting.allowed_user_api_auth_redirects = otp_args[:auth_redirect]
      sign_in(Fabricate(:user, trust_level: TrustLevel[1]))

      post "/user-api-key/otp", params: otp_args
      expect(response.status).to eq(403)
    end

    it "does not allow OTP if one_time_password scope is disabled" do
      SiteSetting.allow_user_api_key_scopes = "read|write"
      SiteSetting.allowed_user_api_auth_redirects = otp_args[:auth_redirect]
      sign_in(Fabricate(:user))

      post "/user-api-key/otp", params: otp_args
      expect(response.status).to eq(403)
    end

    it "returns encrypted OTP and stores it in Redis" do
      SiteSetting.allowed_user_api_auth_redirects = otp_args[:auth_redirect]
      user = Fabricate(:user, refresh_auto_groups: true)
      sign_in(user)

      post "/user-api-key/otp", params: otp_args
      expect(response.status).to eq(302)

      encrypted = extract_payload_from_redirect(response, key: "oneTimePassword")
      otp = decrypt_payload(encrypted)
      expect(Discourse.redis.get("otp_#{otp}")).to eq(user.username)
    end

    it "encrypts OTP with OAEP padding when requested" do
      SiteSetting.allowed_user_api_auth_redirects = otp_args[:auth_redirect]
      user = Fabricate(:user, refresh_auto_groups: true)
      sign_in(user)

      post "/user-api-key/otp", params: otp_args.merge(padding: "oaep")
      expect(response.status).to eq(302)

      encrypted = extract_payload_from_redirect(response, key: "oneTimePassword")
      otp = decrypt_payload(encrypted, padding: "oaep")
      expect(Discourse.redis.get("otp_#{otp}")).to eq(user.username)
    end
  end
end
