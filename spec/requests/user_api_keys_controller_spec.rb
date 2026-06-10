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
    redirect_url = response.redirect_url || response.parsed_body["redirect_url"]
    uri = URI.parse(redirect_url)
    payload = uri.query.split("#{key}=")[1]
    Base64.decode64(CGI.unescape(payload))
  end

  def expect_required_fields(response_body, contract, state)
    required_fields = contract.fetch(state).fetch(:required_fields)
    expect(response_body.keys.map(&:to_sym)).to include(*required_fields)
  end

  describe "#new" do
    it "supports a head request cleanly" do
      head "/user-api-key/new"
      expect(response.status).to eq(200)
      expect(response.headers["Auth-Api-Version"]).to eq("4")
      expect(response.headers["Auth-Api-Device-Code"]).to eq("true")
    end

    it "renders an error for a non-RSA public key even when not logged in" do
      SiteSetting.allowed_user_api_auth_redirects = args[:auth_redirect]
      ec_key = OpenSSL::PKey::EC.generate("prime256v1")
      get "/user-api-key/new.json", params: args.merge(public_key: ec_key.to_pem)
      expect(response.status).to eq(200)
      expect(response.parsed_body["state"]).to eq("generic_error")
    end

    describe "as a normal user" do
      fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }

      before do
        sign_in(user)
        SiteSetting.allowed_user_api_auth_redirects = args[:auth_redirect]
      end

      it "includes padding parameter in the model only when provided" do
        get "/user-api-key/new.json", params: args
        expect(response.parsed_body["padding"]).to be_nil

        get "/user-api-key/new.json", params: args.merge(padding: "oaep")
        expect(response.parsed_body["padding"]).to eq("oaep")
      end

      it "rejects invalid padding parameter" do
        get "/user-api-key/new", params: args.merge(padding: "invalid")
        expect(response.status).to eq(400)
      end

      it "renders an error for a non-RSA public key" do
        ec_key = OpenSSL::PKey::EC.generate("prime256v1")
        get "/user-api-key/new.json", params: args.merge(public_key: ec_key.to_pem)
        expect(response.status).to eq(200)
        expect(response.parsed_body["state"]).to eq("generic_error")
      end

      it "shows write scope warning when write scope is requested" do
        get "/user-api-key/new.json", params: args.merge(scopes: "write")
        expect(response.parsed_body["write_scope"]).to eq(true)
      end

      it "does not show write scope warning for read-only scopes" do
        get "/user-api-key/new.json", params: args
        expect(response.parsed_body["write_scope"]).to eq(false)
      end

      it "does not show redirect warning when auth_redirect is discourse://auth_redirect" do
        SiteSetting.allowed_user_api_auth_redirects = "discourse://auth_redirect"

        get "/user-api-key/new.json", params: args.merge(auth_redirect: "discourse://auth_redirect")
        expect(response.parsed_body["redirect_uri"]).to be_nil
      end

      it "shows redirect warning when auth_redirect is not discourse://auth_redirect" do
        get "/user-api-key/new.json", params: args
        expect(response.parsed_body["redirect_uri"]).to eq("over.the")
      end

      it "shows redirect URI without trailing colon for custom scheme URLs" do
        SiteSetting.allowed_user_api_auth_redirects = "myapp://callback"

        get "/user-api-key/new.json", params: args.merge(auth_redirect: "myapp://callback")
        expect(response.parsed_body["redirect_uri"]).to eq("callback")
      end

      it "rejects auth_redirect to a disallowed domain" do
        get "/user-api-key/new.json", params: args.merge(auth_redirect: "https://evil.com/steal")
        expect(response.parsed_body["state"]).to eq("generic_error")
        expect(response.parsed_body["redirect_uri"]).to be_nil
      end

      it "matches the ready state contract" do
        get "/user-api-key/new.json", params: args

        expect(response.parsed_body["state"]).to eq(
          UserApiKey::DeviceAuth::AUTHORIZATION_STATE_READY,
        )
        expect_required_fields(
          response.parsed_body,
          UserApiKey::DeviceAuth::AUTHORIZATION_STATE_CONTRACT,
          UserApiKey::DeviceAuth::AUTHORIZATION_STATE_READY,
        )
      end

      it "matches the no trust level state contract" do
        SiteSetting.user_api_key_allowed_groups = Group::AUTO_GROUPS[:trust_level_4]

        get "/user-api-key/new.json", params: args

        expect(response.parsed_body["state"]).to eq(
          UserApiKey::DeviceAuth::AUTHORIZATION_STATE_NO_TRUST_LEVEL,
        )
        expect_required_fields(
          response.parsed_body,
          UserApiKey::DeviceAuth::AUTHORIZATION_STATE_CONTRACT,
          UserApiKey::DeviceAuth::AUTHORIZATION_STATE_NO_TRUST_LEVEL,
        )
      end

      it "allows auth_redirect when it matches allowed_user_api_auth_redirects" do
        SiteSetting.allowed_user_api_auth_redirects = "https://good.com/callback"

        get "/user-api-key/new.json", params: args.merge(auth_redirect: "https://good.com/callback")
        expect(response.status).to eq(200)
        expect(response.parsed_body["redirect_uri"]).to eq("good.com")
        expect(response.parsed_body["state"]).to eq("ready")
      end
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
      expect(response.status).to eq(200)
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
      expect(response.status).to eq(200)

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
      expect(response.status).to eq(200)

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

    it "creates keys with a requested expiry" do
      freeze_time
      SiteSetting.user_api_key_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
      user = Fabricate(:user, trust_level: TrustLevel[0])
      sign_in(user)

      post "/user-api-key.json",
           params: args.except(:auth_redirect).merge(expires_in_seconds: 1.day.to_i)
      expect(response.status).to eq(200)

      encrypted = Base64.decode64(response.parsed_body["payload"])
      parsed = JSON.parse(decrypt_payload(encrypted))
      key = UserApiKey.with_key(parsed["key"]).first
      expect(key.expires_at).to eq_time(1.day.from_now)
      expect(parsed["expires_at"]).to eq(key.expires_at.iso8601)
    end

    it "rejects requested expiry greater than the configured maximum" do
      SiteSetting.max_user_api_key_expiry_days = 1
      SiteSetting.user_api_key_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
      sign_in(Fabricate(:user, trust_level: TrustLevel[0]))

      post "/user-api-key.json",
           params: args.except(:auth_redirect).merge(expires_in_seconds: 2.days.to_i)
      expect(response.status).to eq(400)
    end

    it "rejects oversized requested expiry values" do
      SiteSetting.user_api_key_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
      sign_in(Fabricate(:user, trust_level: TrustLevel[0]))

      post "/user-api-key.json",
           params: args.except(:auth_redirect).merge(expires_in_seconds: "1" * 1_000)
      expect(response.status).to eq(400)
    end

    it "renders show template with application_name when no auth_redirect provided" do
      SiteSetting.user_api_key_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
      user = Fabricate(:user, trust_level: TrustLevel[0])
      sign_in(user)

      post "/user-api-key", params: args.except(:auth_redirect)
      expect(response.status).to eq(200)
      expect(response.body).to include(args[:application_name])
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

    it "rejects invalid padding parameter" do
      SiteSetting.user_api_key_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
      sign_in(Fabricate(:user, trust_level: TrustLevel[0]))

      post "/user-api-key.json", params: args.except(:auth_redirect).merge(padding: "invalid")
      expect(response.status).to eq(400)
    end

    it "allows redirect to wildcard urls" do
      SiteSetting.allowed_user_api_auth_redirects = args[:auth_redirect] + "/*"
      sign_in(Fabricate(:user, refresh_auto_groups: true))

      post "/user-api-key.json", params: args.merge(auth_redirect: args[:auth_redirect] + "/foo")
      expect(response.status).to eq(200)
    end

    it "rejects wildcard auth_redirect matches outside the candidate host" do
      SiteSetting.allowed_user_api_auth_redirects = "https://*.example.com/callback"
      sign_in(Fabricate(:user, refresh_auto_groups: true))

      post "/user-api-key.json",
           params: args.merge(auth_redirect: "https://evil.com/path/.example.com/callback")

      expect(response.status).to eq(403)
      expect(response.body).to include("errors")
    end

    it "preserves query params in auth_redirect" do
      SiteSetting.user_api_key_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
      SiteSetting.allowed_user_api_auth_redirects = args[:auth_redirect] + "/*"
      sign_in(Fabricate(:user, trust_level: TrustLevel[0]))

      post "/user-api-key.json", params: args.merge(auth_redirect: args[:auth_redirect] + "/?p=1")
      expect(response.parsed_body["redirect_url"]).to include("?p=1")
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

      before do
        sign_in(user)
        SiteSetting.allowed_user_api_auth_redirects = args[:auth_redirect]
      end

      it "requires registered client auth_redirect to stay on the global allowlist" do
        SiteSetting.allowed_user_api_auth_redirects = "https://good.example.com/callback"

        post "/user-api-key.json", params: args

        expect(response.status).to eq(403)
        expect(response.body).to include("errors")
      end

      it "does not require application_name or public_key params" do
        post "/user-api-key.json", params: args.except(:application_name, :public_key)
        expect(response.status).to eq(200)
      end

      it "rejects scopes not allowed by client" do
        post "/user-api-key.json", params: args.merge(scopes: "write")
        expect(response.status).to eq(403)
      end
    end
  end

  describe "device authorization flow" do
    let(:device_args) { args.except(:auth_redirect).merge(padding: "oaep") }

    def create_pending_device_request(params = {})
      post "/user-api-key/device.json", params: device_args.merge(params), as: :json
      response.parsed_body
    end

    def approval_token_for(user_code, user)
      sign_in(user)
      post "/user-api-key/activate.json", params: { code: user_code }
      response.parsed_body["approval_token"]
    end

    def authorize_device_request(body, user: Fabricate(:user, refresh_auto_groups: true))
      approval_token = approval_token_for(body["user_code"], user)
      post "/user-api-key/device/authorize.json", params: { approval_token: approval_token }
      user
    end

    it "creates a pending request" do
      freeze_time

      body = create_pending_device_request(expires_in_seconds: 1.day.to_i)

      expect(response.status).to eq(200)
      expect(response.headers["Cache-Control"]).to eq("no-store")
      expect(response.headers["Pragma"]).to eq("no-cache")
      expect(response.headers["Expires"]).to eq("0")
      expect(body["device_code"]).to be_present
      expect(body["user_code"]).to match(/\A[A-Z2-9]{4}-[A-Z2-9]{4}\z/)
      expect(body["verification_uri"]).to end_with("/user-api-key/activate")
      expect(body["verification_uri_with_request"]).to include("/user-api-key/activate?request=")
      request_token =
        Rack::Utils.parse_query(URI.parse(body["verification_uri_with_request"]).query)["request"]
      expect(request_token).to match(/\A[-_A-Za-z0-9]{8}\z/)
      expect(body).not_to have_key("verification_uri_complete")
      expect(body["expires_in"]).to eq(10.minutes.to_i)
      expect(body["interval"]).to eq(5)

      grant = JSON.parse(Discourse.redis.get("user_api_key:device:#{body["device_code"]}"))
      expect(grant["status"]).to eq("pending")
      expect(grant["expires_in_seconds"]).to eq(1.day.to_i)
    end

    it "rejects device requests without a JSON content type" do
      post "/user-api-key/device.json", params: device_args

      expect(response.status).to eq(403)
    end

    it "rejects device polls without a JSON content type" do
      body = create_pending_device_request

      post "/user-api-key/device/poll.json", params: { device_code: body["device_code"] }

      expect(response.status).to eq(403)
    end

    it "rejects invalid scopes" do
      create_pending_device_request(scopes: "admin")
      expect(response.status).to eq(403)
    end

    it "rejects invalid public keys" do
      create_pending_device_request(public_key: "not a key")
      expect(response.status).to eq(400)
    end

    it "rejects invalid requested expiries" do
      SiteSetting.max_user_api_key_expiry_days = 1

      create_pending_device_request(expires_in_seconds: 2.days.to_i)
      expect(response.status).to eq(400)
    end

    it "rejects oversized payloads before creating a pending request" do
      request_keys_before = Discourse.redis.keys("user_api_key:device:request:*")
      user_code_keys_before = Discourse.redis.keys("user_api_key:device:code:*")

      create_pending_device_request(nonce: "x" * 150)

      expect(response.status).to eq(400)
      expect(response.parsed_body["errors"].first).to include("Payload too large for OAEP")
      expect(Discourse.redis.keys("user_api_key:device:request:*")).to match_array(
        request_keys_before,
      )
      expect(Discourse.redis.keys("user_api_key:device:code:*")).to match_array(
        user_code_keys_before,
      )
    end

    it "rejects oversized PKCS#1 payloads before creating a pending request" do
      create_pending_device_request(padding: nil, nonce: "x" * 180)

      expect(response.status).to eq(400)
      expect(response.parsed_body["errors"].first).to include("Payload too large for PKCS#1")
    end

    it "allows unregistered clients" do
      body = create_pending_device_request

      expect(response.status).to eq(200)
      grant = JSON.parse(Discourse.redis.get("user_api_key:device:#{body["device_code"]}"))
      expect(grant["unregistered_client"]).to eq(true)
    end

    it "uses registered client metadata and warns when public key is request-supplied" do
      Fabricate(
        :user_api_key_client,
        client_id: args[:client_id],
        application_name: "Stored Client Name",
        public_key: nil,
      )

      body = create_pending_device_request(application_name: "Spoofed Client Name")

      expect(response.status).to eq(200)
      grant = JSON.parse(Discourse.redis.get("user_api_key:device:#{body["device_code"]}"))
      expect(grant["application_name"]).to eq("Stored Client Name")
      expect(grant["unregistered_client"]).to eq(true)
    end

    it "rejects one-time password scope in the device flow" do
      create_pending_device_request(scopes: "one_time_password")

      expect(response.status).to eq(400)
    end

    it "redirects anonymous activation requests to login without preserving codes from URLs" do
      body = create_pending_device_request

      get "/user-api-key/activate", params: { code: body["user_code"] }

      expect(response).to redirect_to("/login")
      expect(response.cookies["destination_url"]).to eq("/user-api-key/activate")
    end

    it "preserves request tokens when redirecting anonymous activation requests to login" do
      body = create_pending_device_request
      request_token =
        Rack::Utils.parse_query(URI.parse(body["verification_uri_with_request"]).query)["request"]

      get "/user-api-key/activate", params: { request: request_token }

      expect(response).to redirect_to("/login")
      expect(response.cookies["destination_url"]).to eq(
        "/user-api-key/activate?request=#{CGI.escape(request_token)}",
      )
    end

    it "returns the code entry page model" do
      sign_in(Fabricate(:user, refresh_auto_groups: true))

      get "/user-api-key/activate.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["state"]).to eq("enter_code")
    end

    it "does not accept codes from query strings" do
      body = create_pending_device_request
      sign_in(Fabricate(:user, refresh_auto_groups: true))

      get "/user-api-key/activate", params: { code: body["user_code"] }

      expect(response).to redirect_to("/user-api-key/activate")
    end

    it "shows the authorization page for a request token before code entry" do
      freeze_time
      body = create_pending_device_request(scopes: "read,write", expires_in_seconds: 1.day.to_i)
      request_token =
        Rack::Utils.parse_query(URI.parse(body["verification_uri_with_request"]).query)["request"]
      user = Fabricate(:user, refresh_auto_groups: true)
      sign_in(user)

      get "/user-api-key/activate.json", params: { request: request_token }

      expect(response.status).to eq(200)
      expect(response.parsed_body["state"]).to eq(
        UserApiKey::DeviceAuth::DEVICE_ACTIVATION_STATE_AUTHORIZE,
      )
      expect_required_fields(
        response.parsed_body,
        UserApiKey::DeviceAuth::DEVICE_ACTIVATION_STATE_CONTRACT,
        UserApiKey::DeviceAuth::DEVICE_ACTIVATION_STATE_AUTHORIZE,
      )
      expect(response.parsed_body["request_token"]).to eq(request_token)
      expect(response.parsed_body["user_code"]).to be_blank
      expect(response.parsed_body["approval_token"]).to be_blank
      expect(response.parsed_body.dig("device_auth", "application_name")).to eq(
        args[:application_name],
      )
      expect(response.parsed_body.dig("device_auth", "localized_scopes")).to contain_exactly(
        I18n.t("user_api_key.scopes.read"),
        I18n.t("user_api_key.scopes.write"),
      )
      expect(response.parsed_body.dig("device_auth", "write_scope")).to eq(true)

      grant = JSON.parse(Discourse.redis.get("user_api_key:device:#{body["device_code"]}"))
      expect(grant["authorizing_user_id"]).to be_blank
    end

    it "does not allow another user to reuse a request token after authorization" do
      body = create_pending_device_request
      request_token =
        Rack::Utils.parse_query(URI.parse(body["verification_uri_with_request"]).query)["request"]
      first_user = Fabricate(:user, refresh_auto_groups: true)
      second_user = Fabricate(:user, refresh_auto_groups: true)

      sign_in(first_user)
      get "/user-api-key/activate", params: { request: request_token }
      expect(response.status).to eq(200)
      post "/user-api-key/device/authorize.json",
           params: {
             request: request_token,
             code: body["user_code"].delete("-"),
           }
      expect(response.parsed_body["state"]).to eq(
        UserApiKey::DeviceAuth::DEVICE_ACTIVATION_STATE_COMPLETE,
      )
      expect_required_fields(
        response.parsed_body,
        UserApiKey::DeviceAuth::DEVICE_ACTIVATION_STATE_CONTRACT,
        UserApiKey::DeviceAuth::DEVICE_ACTIVATION_STATE_COMPLETE,
      )

      sign_in(second_user)
      post "/user-api-key/device/authorize.json",
           params: {
             request: request_token,
             code: body["user_code"].delete("-"),
           }
      expect(response.parsed_body["state"]).not_to eq("complete")
    end

    it "shows the authorization page for a manually submitted valid code" do
      freeze_time
      body = create_pending_device_request(scopes: "read,write", expires_in_seconds: 1.day.to_i)
      user = Fabricate(:user, refresh_auto_groups: true)
      sign_in(user)

      post "/user-api-key/activate.json", params: { code: body["user_code"].delete("-") }

      expect(response.status).to eq(200)
      expect(response.parsed_body["state"]).to eq("authorize")
      expect(response.parsed_body["approval_token"]).to be_present
      expect(response.parsed_body.dig("device_auth", "application_name")).to eq(
        args[:application_name],
      )
      expect(response.parsed_body.dig("device_auth", "localized_scopes")).to contain_exactly(
        I18n.t("user_api_key.scopes.read"),
        I18n.t("user_api_key.scopes.write"),
      )
      expect(response.parsed_body.dig("device_auth", "write_scope")).to eq(true)
      expect(response.parsed_body.dig("device_auth", "unregistered_client")).to eq(true)
      expect(response.parsed_body.dig("device_auth", "expires_at")).to eq(1.day.from_now.iso8601)
      expect(Discourse.redis.get("user_api_key:device:code:#{body["user_code"]}")).to eq(
        body["device_code"],
      )

      grant = UserApiKey::DeviceAuth::GrantStore.load(body["device_code"])
      expect(grant.authorizing_user_id).to eq(user.id)
    end

    it "does not allow another user to claim a manual code after the first user reaches confirmation" do
      body = create_pending_device_request
      request_token =
        Rack::Utils.parse_query(URI.parse(body["verification_uri_with_request"]).query)["request"]
      first_user = Fabricate(:user, refresh_auto_groups: true)
      second_user = Fabricate(:user, refresh_auto_groups: true)

      sign_in(first_user)
      post "/user-api-key/activate.json", params: { code: body["user_code"] }
      expect(response.parsed_body["approval_token"]).to be_present

      sign_in(second_user)
      post "/user-api-key/activate.json", params: { code: body["user_code"] }

      expect(response.parsed_body["expired_code"]).to eq(true)
      expect(response.parsed_body["approval_token"]).to be_blank

      post "/user-api-key/device/authorize.json",
           params: {
             request: request_token,
             code: body["user_code"],
           }
      expect(response.parsed_body["state"]).to eq("enter_code")
      expect(response.parsed_body["expired_code"]).to eq(true)
    end

    it "warns when no expiry is requested" do
      body = create_pending_device_request
      sign_in(Fabricate(:user, refresh_auto_groups: true))

      post "/user-api-key/activate.json", params: { code: body["user_code"] }

      expect(response.status).to eq(200)
      expect(response.parsed_body.dig("device_auth", "expires_at")).to be_nil
    end

    it "does not consume a manual user code for users who cannot authorize keys" do
      body = create_pending_device_request
      SiteSetting.user_api_key_allowed_groups = Group::AUTO_GROUPS[:trust_level_4]
      sign_in(Fabricate(:user, trust_level: TrustLevel[0]))

      post "/user-api-key/activate.json", params: { code: body["user_code"] }

      expect(response.status).to eq(200)
      expect(response.parsed_body["no_trust_level"]).to eq(true)
      expect(Discourse.redis.get("user_api_key:device:code:#{body["user_code"]}")).to eq(
        body["device_code"],
      )
      SiteSetting.user_api_key_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
    end

    it "does not allow an approval token to be reused by another user" do
      body = create_pending_device_request
      first_user = Fabricate(:user, refresh_auto_groups: true)
      second_user = Fabricate(:user, refresh_auto_groups: true)
      approval_token = approval_token_for(body["user_code"], first_user)
      sign_in(second_user)

      post "/user-api-key/device/authorize.json", params: { approval_token: approval_token }

      expect(response.parsed_body["expired_code"]).to eq(true)
      post "/user-api-key/device/poll.json", params: { device_code: body["device_code"] }, as: :json
      expect(response.parsed_body["status"]).to eq("authorization_pending")
    end

    it "shows a safe error for invalid codes" do
      sign_in(Fabricate(:user, refresh_auto_groups: true))

      post "/user-api-key/activate.json", params: { code: "BAD-CODE" }

      expect(response.status).to eq(200)
      expect(response.parsed_body["invalid_code"]).to eq(true)
      expect(response.parsed_body["device_auth"]).to be_blank
    end

    it "returns authorization_pending while waiting for authorization" do
      body = create_pending_device_request

      post "/user-api-key/device/poll.json", params: { device_code: body["device_code"] }, as: :json

      expect(response.status).to eq(200)
      expect(response.parsed_body["status"]).to eq("authorization_pending")
    end

    it "authorizes a pending request with a request token and typed code" do
      freeze_time
      body = create_pending_device_request(scopes: "read,write", expires_in_seconds: 1.day.to_i)
      request_token =
        Rack::Utils.parse_query(URI.parse(body["verification_uri_with_request"]).query)["request"]
      user = Fabricate(:user, refresh_auto_groups: true)
      sign_in(user)
      get "/user-api-key/activate", params: { request: request_token }

      post "/user-api-key/device/authorize.json",
           params: {
             request: request_token,
             code: body["user_code"].delete("-"),
           }

      expect(response.status).to eq(200)
      expect(response.parsed_body["state"]).to eq("complete")

      post "/user-api-key/device/poll.json", params: { device_code: body["device_code"] }, as: :json

      expect(response.parsed_body["status"]).to eq("authorized")
      encrypted = Base64.decode64(response.parsed_body["payload"])
      parsed = JSON.parse(decrypt_payload(encrypted, padding: "oaep"))
      key = UserApiKey.with_key(parsed["key"]).first

      expect(parsed["nonce"]).to eq(args[:nonce])
      expect(parsed["api"]).to eq(4)
      expect(parsed["expires_at"]).to eq(1.day.from_now.iso8601)
      expect(key.user_id).to eq(user.id)
      expect(key.expires_at).to eq_time(1.day.from_now)
      expect(key.scopes.map(&:name).sort).to eq(%w[read write])
    end

    it "keeps request context and does not authorize when request token code is wrong" do
      body = create_pending_device_request
      request_token =
        Rack::Utils.parse_query(URI.parse(body["verification_uri_with_request"]).query)["request"]
      sign_in(Fabricate(:user, refresh_auto_groups: true))
      get "/user-api-key/activate", params: { request: request_token }

      post "/user-api-key/device/authorize.json",
           params: {
             request: request_token,
             code: "BADCODE1",
           }

      expect(response.status).to eq(200)
      expect(response.parsed_body["invalid_code"]).to eq(true)
      expect(response.parsed_body.dig("device_auth", "application_name")).to eq(
        args[:application_name],
      )
      expect(response.parsed_body["request_token"]).to eq(request_token)
      expect(response.parsed_body["user_code"]).to be_blank

      post "/user-api-key/device/poll.json", params: { device_code: body["device_code"] }, as: :json
      expect(response.parsed_body["status"]).to eq("authorization_pending")
    end

    it "authorizes a pending request and returns an encrypted payload when polled" do
      freeze_time
      body = create_pending_device_request(scopes: "read,write", expires_in_seconds: 1.day.to_i)
      user = authorize_device_request(body)

      expect(response.status).to eq(200)
      expect(response.parsed_body["state"]).to eq("complete")

      post "/user-api-key/device/poll.json", params: { device_code: body["device_code"] }, as: :json

      expect(response.parsed_body["status"]).to eq("authorized")
      encrypted = Base64.decode64(response.parsed_body["payload"])
      parsed = JSON.parse(decrypt_payload(encrypted, padding: "oaep"))
      key = UserApiKey.with_key(parsed["key"]).first

      expect(parsed["nonce"]).to eq(args[:nonce])
      expect(parsed["api"]).to eq(4)
      expect(parsed["expires_at"]).to eq(1.day.from_now.iso8601)
      expect(key.user_id).to eq(user.id)
      expect(key.expires_at).to eq_time(1.day.from_now)
      expect(key.scopes.map(&:name).sort).to eq(%w[read write])

      post "/user-api-key/device/poll.json", params: { device_code: body["device_code"] }, as: :json
      expect(response.parsed_body["status"]).to eq("expired_token")
    end

    it "returns access_denied when a pending request is denied" do
      body = create_pending_device_request
      user = Fabricate(:user, refresh_auto_groups: true)
      approval_token = approval_token_for(body["user_code"], user)

      post "/user-api-key/device/deny.json", params: { approval_token: approval_token }
      expect(response.parsed_body["denied"]).to eq(true)

      post "/user-api-key/device/poll.json", params: { device_code: body["device_code"] }, as: :json
      expect(response.parsed_body["status"]).to eq("access_denied")
    end

    it "does not report denied for an invalid approval token" do
      sign_in(Fabricate(:user, refresh_auto_groups: true))

      post "/user-api-key/device/deny.json", params: { approval_token: SecureRandom.hex(32) }

      expect(response.parsed_body["expired_code"]).to eq(true)
      expect(response.parsed_body["denied"]).not_to eq(true)
    end

    it "does not allow request-token denial without an approval token" do
      body = create_pending_device_request
      request_token =
        Rack::Utils.parse_query(URI.parse(body["verification_uri_with_request"]).query)["request"]
      sign_in(Fabricate(:user, refresh_auto_groups: true))
      get "/user-api-key/activate", params: { request: request_token }

      post "/user-api-key/device/deny.json", params: { request: request_token }
      expect(response.parsed_body["expired_code"]).to eq(true)

      post "/user-api-key/device/poll.json", params: { device_code: body["device_code"] }, as: :json
      expect(response.parsed_body["status"]).to eq("authorization_pending")
    end

    it "returns expired_token for expired or missing requests" do
      post "/user-api-key/device/poll.json",
           params: {
             device_code: SecureRandom.hex(32),
           },
           as: :json

      expect(response.status).to eq(200)
      expect(response.parsed_body["status"]).to eq("expired_token")
    end

    it "enforces registered client scope restrictions" do
      Fabricate(
        :user_api_key_client,
        client_id: args[:client_id],
        application_name: args[:application_name],
        public_key: public_key,
        scopes: "read",
      )

      create_pending_device_request(scopes: "write")

      expect(response.status).to eq(403)
    end

    context "with rate limiting enabled" do
      before { RateLimiter.enable }
      after { RateLimiter.disable }

      it "rate limits device request creation" do
        UserApiKeysController::DEVICE_REQUESTS_PER_MINUTE.times do |i|
          create_pending_device_request(client_id: "device-client-#{i}")
          expect(response.status).to eq(200)
        end

        create_pending_device_request(client_id: "device-client-limited")
        expect(response.status).to eq(429)
      end

      it "rate limits invalid code entry" do
        user = Fabricate(:user, refresh_auto_groups: true)
        sign_in(user)

        UserApiKeysController::DEVICE_ACTIVATION_ATTEMPTS_PER_MINUTE.times do |i|
          post "/user-api-key/activate", params: { code: "BADCODE#{i}" }
          expect(response.status).to eq(200)
        end

        post "/user-api-key/activate", params: { code: "LIMITED1" }
        expect(response.status).to eq(429)
      end

      it "rate limits request token lookup" do
        sign_in(Fabricate(:user, refresh_auto_groups: true))

        UserApiKeysController::DEVICE_REQUEST_TOKEN_LOOKUPS_PER_MINUTE.times do |i|
          get "/user-api-key/activate", params: { request: "A00000#{format("%02d", i)}" }
          expect(response.status).to eq(200)
        end

        get "/user-api-key/activate", params: { request: "LIMITED1" }
        expect(response.status).to eq(429)
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
    it "includes padding parameter in the model only when provided" do
      SiteSetting.allowed_user_api_auth_redirects = otp_args[:auth_redirect]
      sign_in(Fabricate(:user, refresh_auto_groups: true))

      get "/user-api-key/otp.json", params: otp_args
      expect(response.parsed_body["padding"]).to be_nil

      get "/user-api-key/otp.json", params: otp_args.merge(padding: "oaep")
      expect(response.parsed_body["padding"]).to eq("oaep")
    end

    it "rejects invalid padding parameter" do
      sign_in(Fabricate(:user, refresh_auto_groups: true))

      get "/user-api-key/otp", params: otp_args.merge(padding: "invalid")
      expect(response.status).to eq(400)
    end

    it "rejects auth_redirect outside the allowlist" do
      SiteSetting.allowed_user_api_auth_redirects = "https://good.example.com/callback"

      get "/user-api-key/otp",
          params: otp_args.merge(auth_redirect: "https://evil.example.com/callback")

      expect(response.status).to eq(403)
    end

    it "does not show the form when auth_redirect differs from a registered client's redirect" do
      SiteSetting.allowed_user_api_auth_redirects = "https://*.example.com/callback"

      Fabricate(
        :user_api_key_client,
        public_key: public_key,
        auth_redirect: "https://legitimate.example.com/callback",
      )

      get "/user-api-key/otp",
          params: otp_args.merge(auth_redirect: "https://evil.example.com/callback")

      expect(response.status).to eq(403)
    end

    it "rejects a non-RSA public key with 400" do
      SiteSetting.allowed_user_api_auth_redirects = otp_args[:auth_redirect]
      ec_key = OpenSSL::PKey::EC.generate("prime256v1")
      get "/user-api-key/otp", params: otp_args.merge(public_key: ec_key.to_pem)
      expect(response.status).to eq(400)
    end
  end

  describe "#create_otp" do
    it "does not allow anon" do
      post "/user-api-key/otp", params: otp_args
      expect(response.status).to eq(403)
    end

    it "rejects auth_redirect outside the allowlist" do
      SiteSetting.allowed_user_api_auth_redirects = "https://good.example.com/callback"
      sign_in(Fabricate(:user))

      post "/user-api-key/otp",
           params: otp_args.merge(auth_redirect: "https://evil.example.com/callback")

      expect(response.status).to eq(403)
    end

    it "does not allow auth_redirect that differs from a registered client's redirect" do
      SiteSetting.allowed_user_api_auth_redirects = "https://*.example.com/callback"
      sign_in(Fabricate(:user, refresh_auto_groups: true))

      Fabricate(
        :user_api_key_client,
        public_key: public_key,
        auth_redirect: "https://legitimate.example.com/callback",
      )

      post "/user-api-key/otp",
           params: otp_args.merge(auth_redirect: "https://evil.example.com/callback")

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

    it "rejects invalid padding parameter" do
      SiteSetting.allowed_user_api_auth_redirects = otp_args[:auth_redirect]
      sign_in(Fabricate(:user, refresh_auto_groups: true))

      post "/user-api-key/otp", params: otp_args.merge(padding: "invalid")
      expect(response.status).to eq(400)
    end
  end
end
