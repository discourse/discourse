# frozen_string_literal: true

RSpec.describe Auth::SessionConfirmation do
  fab!(:user) { Fabricate(:user, password: "supersecurepassword") }
  fab!(:other_user, :user)

  let(:server_session) { ServerSession.new("test-session-#{SecureRandom.hex(8)}") }
  let(:token) { UserAuthToken.generate!(user_id: user.id) }

  def build_request(user_token: token, env_overrides: {}, session: server_session)
    req = ActionDispatch::TestRequest.create
    req.env[Auth::DefaultCurrentUserProvider::USER_TOKEN_KEY] = user_token if user_token
    env_overrides.each { |k, v| req.env[k] = v }
    req.stubs(:server_session).returns(session)
    req
  end

  describe ".mark_fresh_login! and .fresh_login?" do
    it "grants trust for FRESH_LOGIN_LIFETIME and expires afterward" do
      freeze_time
      req = build_request

      described_class.mark_fresh_login!(req, user)
      expect(described_class.fresh_login?(req, user)).to eq(true)

      freeze_time((described_class::FRESH_LOGIN_LIFETIME - 1.second).from_now)
      expect(described_class.fresh_login?(req, user)).to eq(true)

      freeze_time(2.seconds.from_now)
      expect(described_class.fresh_login?(req, user)).to eq(false)
    end

    it "survives token rotation while remaining bound to the token id and user" do
      req = build_request
      described_class.mark_fresh_login!(req, user)

      token.rotate!
      expect(described_class.fresh_login?(req, user)).to eq(true)

      other_token = UserAuthToken.generate!(user_id: user.id)
      other_req = build_request(user_token: other_token)
      expect(described_class.fresh_login?(other_req, user)).to eq(false)
      expect(described_class.fresh_login?(req, other_user)).to eq(false)
    end

    it "ignores API, user API, shared-session, anonymous, and impersonated requests" do
      api_req =
        build_request(env_overrides: { Auth::DefaultCurrentUserProvider::API_KEY_ENV => true })
      user_api_req =
        build_request(env_overrides: { Auth::DefaultCurrentUserProvider::USER_API_KEY_ENV => true })
      shared_req = build_request(env_overrides: { "HTTP_X_SHARED_SESSION_KEY" => "v2_abc" })

      described_class.mark_fresh_login!(api_req, user)
      expect(described_class.fresh_login?(build_request, user)).to eq(false)
      expect(described_class.fresh_login?(api_req, user)).to eq(false)
      expect(described_class.fresh_login?(user_api_req, user)).to eq(false)
      expect(described_class.fresh_login?(shared_req, user)).to eq(false)

      SiteSetting.allow_anonymous_mode = true
      anon_user = Fabricate(:anonymous)
      anon_token = UserAuthToken.generate!(user_id: anon_user.id)
      anon_req = build_request(user_token: anon_token)
      described_class.mark_fresh_login!(anon_req, anon_user)
      expect(described_class.fresh_login?(anon_req, anon_user)).to eq(false)

      user.is_impersonating = true
      impersonated_req = build_request
      described_class.mark_fresh_login!(impersonated_req, user)
      expect(described_class.fresh_login?(impersonated_req, user)).to eq(false)
    end
  end

  describe ".mark_confirmed! and .confirmed?" do
    it "respects local_logins_available for local confirmations but keeps external confirmations valid" do
      req = build_request

      expect(described_class.mark_confirmed!(req, user, local: true)).to eq(true)
      expect(described_class.confirmed?(req, user, local_logins_available: true)).to eq(true)
      expect(described_class.confirmed?(req, user, local_logins_available: false)).to eq(false)

      expect(described_class.mark_confirmed!(req, user, local: false)).to eq(true)
      expect(described_class.confirmed?(req, user, local_logins_available: false)).to eq(true)
    end

    it "does not transfer confirmation across browser tokens" do
      req = build_request
      described_class.mark_confirmed!(req, user, local: true)

      other_token = UserAuthToken.generate!(user_id: user.id)
      other_req = build_request(user_token: other_token)
      expect(described_class.confirmed?(other_req, user, local_logins_available: true)).to eq(false)
    end
  end

  describe ".issue_email_code! and .verify_email_code!" do
    it "issues a session_confirmation code, verifies it once, and confirms the session" do
      req = build_request
      login_code = nil

      expect do login_code = described_class.issue_email_code!(req, user) end.to change {
        EmailLoginCode.session_confirmation.count
      }.by(1)

      expect(
        job_enqueued?(
          job: :send_session_confirmation_code,
          args: {
            user_id: user.id,
            to_address: user.email,
            code: login_code.code,
          },
        ),
      ).to eq(true)

      expect(described_class.verify_email_code!(req, user, login_code.code)).to eq(true)
      expect(described_class.confirmed?(req, user, local_logins_available: true)).to eq(true)
      expect(login_code.reload.consumed_at).to be_present

      expect(described_class.verify_email_code!(req, user, login_code.code)).to eq(false)
    end

    it "rejects wrong codes, locks out after MAX_ATTEMPTS, and rejects expired or cross-purpose codes" do
      req = build_request
      login_code = described_class.issue_email_code!(req, user)
      wrong_code = login_code.code == "000000" ? "000001" : "000000"

      (EmailLoginCode::MAX_ATTEMPTS - 1).times do
        expect(described_class.verify_email_code!(req, user, wrong_code)).to eq(false)
        expect(req.server_session[described_class::EMAIL_CODE_SESSION_KEY]).to be_present
      end

      expect(described_class.verify_email_code!(req, user, wrong_code)).to eq(false)
      expect(req.server_session[described_class::EMAIL_CODE_SESSION_KEY]).to be_nil
      expect(described_class.verify_email_code!(req, user, login_code.code)).to eq(false)

      login_purpose_code = EmailLoginCode.generate!(email: user.email, purpose: :login)
      req.server_session[described_class::EMAIL_CODE_SESSION_KEY] = {
        login_code_id: login_purpose_code.id,
        user_id: user.id,
        token_id: token.id,
      }
      expect(described_class.verify_email_code!(req, user, login_purpose_code.code)).to eq(false)
    end

    it "rejects a code if the user's email changes or the session token differs" do
      req = build_request
      login_code = described_class.issue_email_code!(req, user)

      other_token = UserAuthToken.generate!(user_id: user.id)
      other_req = build_request(user_token: other_token)
      expect(described_class.verify_email_code!(other_req, user, login_code.code)).to eq(false)

      user.primary_email.update!(email: "changed-#{SecureRandom.hex(4)}@example.com")
      expect(described_class.verify_email_code!(req, user, login_code.code)).to eq(false)
    end
  end

  describe ".start_external_confirmation!, .consume_external_confirmation!, and .clear_external_confirmation!" do
    it "stores, consumes once, and clears external confirmation intent" do
      req = build_request
      expect(
        described_class.start_external_confirmation!(req, user, provider: :google_oauth2),
      ).to eq(true)

      data = described_class.consume_external_confirmation!(req)
      expect(data).to eq(user_id: user.id, token_id: token.id, provider: "google_oauth2")
      expect(described_class.consume_external_confirmation!(req)).to be_nil

      described_class.start_external_confirmation!(req, user, provider: "google_oauth2")
      described_class.clear_external_confirmation!(req)
      expect(described_class.consume_external_confirmation!(req)).to be_nil
    end
  end

  describe ".connected_external_providers" do
    before { enable_auth_provider(:google_oauth2) }

    it "returns enabled authenticators connected to the user unless SSO is enabled" do
      Fabricate(
        :user_associated_account,
        user:,
        provider_name: "google_oauth2",
        provider_uid: "123",
      )

      expect(described_class.connected_external_providers(user)).to eq(["google_oauth2"])
      expect(described_class.connected_external_providers(other_user)).to eq([])

      SiteSetting.discourse_connect_url = "https://example.com/sso"
      SiteSetting.discourse_connect_secret = "x" * 10
      SiteSetting.enable_discourse_connect = true
      expect(described_class.connected_external_providers(user)).to eq([])
    end

    it "excludes providers configured with a custom_url" do
      standard_auth = mock("standard_auth")
      standard_auth.stubs(:name).returns("google_oauth2")
      standard_auth.stubs(:description_for_user).with(user).returns("user@example.com")

      custom_url_auth = mock("custom_url_auth")
      custom_url_auth.stubs(:name).returns("custom_sso")
      custom_url_auth.stubs(:description_for_user).with(user).returns("user@example.com")

      Discourse.stubs(:enabled_auth_providers).returns(
        [
          Auth::AuthProvider.new(authenticator: standard_auth),
          Auth::AuthProvider.new(
            authenticator: custom_url_auth,
            custom_url: "https://example.com/auth",
          ),
        ],
      )

      expect(described_class.connected_external_providers(user)).to eq(["google_oauth2"])
    end
  end
end
