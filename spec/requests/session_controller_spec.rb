# frozen_string_literal: true

require "rotp"

RSpec.describe SessionController do
  let(:user) { Fabricate(:user) }
  let(:email_token) { Fabricate(:email_token, user: user) }

  fab!(:admin)
  let(:admin_email_token) { Fabricate(:email_token, user: admin) }

  shared_examples "failed to continue local login" do
    it "should return the right response" do
      expect(response).not_to be_successful
      expect(response.status).to eq(403)
    end
  end

  before { SiteSetting.hide_email_address_taken = false }

  describe "#email_login_info" do
    let(:email_token) do
      Fabricate(:email_token, user: user, scope: EmailToken.scopes[:email_login])
    end

    before { SiteSetting.enable_local_logins_via_email = true }

    context "when local logins via email disabled" do
      before { SiteSetting.enable_local_logins_via_email = false }

      it "only works for admins" do
        get "/session/email-login/#{email_token.token}.json"
        expect(response.status).to eq(403)

        user.update(admin: true)
        get "/session/email-login/#{email_token.token}.json"
        expect(response.status).to eq(200)
        expect(response.parsed_body["error"]).not_to be_present
      end
    end

    context "when SSO enabled" do
      before do
        SiteSetting.discourse_connect_url = "https://www.example.com/sso"
        SiteSetting.enable_discourse_connect = true
      end

      it "only works for admins" do
        get "/session/email-login/#{email_token.token}.json"
        expect(response.status).to eq(403)

        user.update(admin: true)
        get "/session/email-login/#{email_token.token}.json"
        expect(response.status).to eq(200)
        expect(response.parsed_body["error"]).not_to be_present
      end
    end

    context "with missing token" do
      it "returns the right response" do
        get "/session/email-login"
        expect(response.status).to eq(404)
      end
    end

    context "with valid token" do
      it "returns information" do
        get "/session/email-login/#{email_token.token}.json"

        expect(response.parsed_body["can_login"]).to eq(true)
        expect(response.parsed_body["second_factor_required"]).to eq(nil)

        # Does not log in the user
        expect(session[:current_user_id]).to be_nil
      end

      it "fails when local logins via email is disabled" do
        SiteSetting.enable_local_logins_via_email = false

        get "/session/email-login/#{email_token.token}.json"

        expect(response.status).to eq(403)
      end

      it "fails when local logins is disabled" do
        SiteSetting.enable_local_logins = false

        get "/session/email-login/#{email_token.token}.json"

        expect(response.status).to eq(403)
      end

      context "when user has 2-factor logins" do
        let!(:user_second_factor) { Fabricate(:user_second_factor_totp, user: user) }
        let!(:user_second_factor_backup) { Fabricate(:user_second_factor_backup, user: user) }

        it "includes that information in the response" do
          get "/session/email-login/#{email_token.token}.json"

          response_body_parsed = response.parsed_body
          expect(response_body_parsed["can_login"]).to eq(true)
          expect(response_body_parsed["second_factor_required"]).to eq(true)
          expect(response_body_parsed["backup_codes_enabled"]).to eq(true)
          expect(response_body_parsed["totp_enabled"]).to eq(true)
        end
      end

      context "when user has security key enabled" do
        let!(:user_security_key) { Fabricate(:user_security_key, user: user) }

        it "includes that information in the response" do
          get "/session/email-login/#{email_token.token}.json"

          response_body_parsed = response.parsed_body
          expect(response_body_parsed["can_login"]).to eq(true)
          expect(response_body_parsed["security_key_required"]).to eq(true)
          expect(response_body_parsed["second_factor_required"]).to eq(nil)
          expect(response_body_parsed["backup_codes_enabled"]).to eq(nil)
          expect(response_body_parsed["allowed_credential_ids"]).to eq(
            [user_security_key.credential_id],
          )
          secure_session = SecureSession.new(session["secure_session_id"])

          expect(response_body_parsed["challenge"]).to eq(
            DiscourseWebauthn.challenge(user, secure_session),
          )
          expect(DiscourseWebauthn.rp_id).to eq("localhost")
        end
      end
    end
  end

  describe "#email_login" do
    let(:email_token) do
      Fabricate(:email_token, user: user, scope: EmailToken.scopes[:email_login])
    end

    before { SiteSetting.enable_local_logins_via_email = true }

    context "when in staff writes only mode" do
      before { Discourse.enable_readonly_mode(Discourse::STAFF_WRITES_ONLY_MODE_KEY) }

      it "allows admins to login" do
        user.update!(admin: true)
        post "/session/email-login/#{email_token.token}.json"
        expect(response.status).to eq(200)
        expect(session[:current_user_id]).to eq(user.id)
      end

      it "does not allow other users to login" do
        post "/session/email-login/#{email_token.token}.json"
        expect(response.status).to eq(503)
        expect(session[:current_user_id]).to eq(nil)
      end
    end

    context "when local logins via email disabled" do
      before { SiteSetting.enable_local_logins_via_email = false }

      it "only works for admins" do
        post "/session/email-login/#{email_token.token}.json"
        expect(response.status).to eq(403)

        user.update(admin: true)
        post "/session/email-login/#{email_token.token}.json"
        expect(response.status).to eq(200)
        expect(response.parsed_body["error"]).not_to be_present
        expect(session[:current_user_id]).to eq(user.id)
      end
    end

    context "with missing token" do
      it "returns the right response" do
        post "/session/email-login"
        expect(response.status).to eq(404)
      end
    end

    context "with invalid token" do
      it "returns the right response" do
        post "/session/email-login/adasdad.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["error"]).to eq(
          I18n.t("email_login.invalid_token", base_url: Discourse.base_url),
        )
      end

      context "when token has expired" do
        it "should return the right response" do
          email_token.update!(created_at: 999.years.ago)

          post "/session/email-login/#{email_token.token}.json"

          expect(response.status).to eq(200)

          expect(response.parsed_body["error"]).to eq(
            I18n.t("email_login.invalid_token", base_url: Discourse.base_url),
          )
        end
      end
    end

    context "with valid token" do
      it "returns success" do
        post "/session/email-login/#{email_token.token}.json"

        expect(response.parsed_body["success"]).to eq("OK")
        expect(session[:current_user_id]).to eq(user.id)
      end

      it "fails when local logins via email is disabled" do
        SiteSetting.enable_local_logins_via_email = false

        post "/session/email-login/#{email_token.token}.json"

        expect(response.status).to eq(403)
        expect(session[:current_user_id]).to eq(nil)
      end

      it "fails when local logins is disabled" do
        SiteSetting.enable_local_logins = false

        post "/session/email-login/#{email_token.token}.json"

        expect(response.status).to eq(403)
        expect(session[:current_user_id]).to eq(nil)
      end

      it "doesn't log in the user when not approved" do
        SiteSetting.must_approve_users = true

        post "/session/email-login/#{email_token.token}.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["error"]).to eq(I18n.t("login.not_approved"))
        expect(session[:current_user_id]).to eq(nil)
      end

      context "when admin IP address is not valid" do
        before do
          Fabricate(
            :screened_ip_address,
            ip_address: "111.111.11.11",
            action_type: ScreenedIpAddress.actions[:allow_admin],
          )

          SiteSetting.use_admin_ip_allowlist = true
          user.update!(admin: true)
        end

        it "returns the right response" do
          post "/session/email-login/#{email_token.token}.json"

          expect(response.status).to eq(200)

          expect(response.parsed_body["error"]).to eq(
            I18n.t("login.admin_not_allowed_from_ip_address", username: user.username),
          )
          expect(session[:current_user_id]).to eq(nil)
        end
      end

      context "when IP address is blocked" do
        let(:permitted_ip_address) { "111.234.23.11" }

        before do
          Fabricate(
            :screened_ip_address,
            ip_address: permitted_ip_address,
            action_type: ScreenedIpAddress.actions[:block],
          )
        end

        it "returns the right response" do
          ActionDispatch::Request.any_instance.stubs(:remote_ip).returns(permitted_ip_address)

          post "/session/email-login/#{email_token.token}.json"

          expect(response.status).to eq(200)

          expect(response.parsed_body["error"]).to eq(
            I18n.t("login.not_allowed_from_ip_address", username: user.username),
          )
          expect(session[:current_user_id]).to eq(nil)
        end
      end

      context "when timezone param is provided" do
        it "sets the user_option timezone for the user" do
          post "/session/email-login/#{email_token.token}.json",
               params: {
                 timezone: "Australia/Melbourne",
               }
          expect(response.status).to eq(200)
          expect(response.parsed_body["error"]).not_to be_present
          expect(user.reload.user_option.timezone).to eq("Australia/Melbourne")
        end
      end

      it "fails when user is suspended" do
        user.update!(suspended_till: 2.days.from_now, suspended_at: Time.zone.now)

        post "/session/email-login/#{email_token.token}.json"

        expect(response.status).to eq(200)

        expect(response.parsed_body["error"]).to eq(
          I18n.t("login.suspended", date: I18n.l(user.suspended_till, format: :date_only)),
        )
        expect(session[:current_user_id]).to eq(nil)
      end

      context "when user has 2-factor logins" do
        let!(:user_second_factor) { Fabricate(:user_second_factor_totp, user: user) }
        let!(:user_second_factor_backup) { Fabricate(:user_second_factor_backup, user: user) }

        describe "errors on incorrect 2-factor" do
          context "when using totp method" do
            it "does not log in with incorrect two factor" do
              post "/session/email-login/#{email_token.token}.json",
                   params: {
                     second_factor_token: "0000",
                     second_factor_method: UserSecondFactor.methods[:totp],
                   }

              expect(response.status).to eq(200)

              expect(response.parsed_body["error"]).to eq(
                I18n.t("login.invalid_second_factor_code"),
              )
              expect(session[:current_user_id]).to eq(nil)
            end
          end
          context "when using backup code method" do
            it "does not log in with incorrect backup code" do
              post "/session/email-login/#{email_token.token}.json",
                   params: {
                     second_factor_token: "0000",
                     second_factor_method: UserSecondFactor.methods[:backup_codes],
                   }

              expect(response.status).to eq(200)
              expect(response.parsed_body["error"]).to eq(
                I18n.t("login.invalid_second_factor_code"),
              )
              expect(session[:current_user_id]).to eq(nil)
            end
          end
        end

        describe "allows successful 2-factor" do
          context "when using totp method" do
            it "logs in correctly" do
              post "/session/email-login/#{email_token.token}.json",
                   params: {
                     second_factor_token: ROTP::TOTP.new(user_second_factor.data).now,
                     second_factor_method: UserSecondFactor.methods[:totp],
                   }

              expect(response.parsed_body["success"]).to eq("OK")
              expect(session[:current_user_id]).to eq(user.id)
            end
          end
          context "when using backup code method" do
            it "logs in correctly" do
              post "/session/email-login/#{email_token.token}.json",
                   params: {
                     second_factor_token: "iAmValidBackupCode",
                     second_factor_method: UserSecondFactor.methods[:backup_codes],
                   }

              expect(response.parsed_body["success"]).to eq("OK")
              expect(session[:current_user_id]).to eq(user.id)
            end
          end
        end

        context "if the security_key_param is provided but only TOTP is enabled" do
          it "does not log in the user" do
            post "/session/email-login/#{email_token.token}.json",
                 params: {
                   second_factor_token: "foo",
                   second_factor_method: UserSecondFactor.methods[:totp],
                 }

            expect(response.status).to eq(200)

            expect(response.parsed_body["error"]).to eq(I18n.t("login.invalid_second_factor_code"))
            expect(session[:current_user_id]).to eq(nil)
          end
        end
      end

      context "when user has only security key enabled" do
        let!(:user_security_key) do
          Fabricate(
            :user_security_key,
            user: user,
            credential_id: valid_security_key_data[:credential_id],
            public_key: valid_security_key_data[:public_key],
          )
        end

        before do
          simulate_localhost_webauthn_challenge
          DiscourseWebauthn.stubs(:origin).returns("http://localhost:3000")

          # store challenge in secure session by visiting the email login page
          get "/session/email-login/#{email_token.token}.json"
        end

        context "when the security key params are blank and a random second factor token is provided" do
          it "shows an error message and denies login" do
            post "/session/email-login/#{email_token.token}.json",
                 params: {
                   second_factor_token: "XXXXXXX",
                   second_factor_method: UserSecondFactor.methods[:totp],
                 }

            expect(response.status).to eq(200)
            expect(session[:current_user_id]).to eq(nil)
            response_body = response.parsed_body
            expect(response_body["error"]).to eq(I18n.t("login.not_enabled_second_factor_method"))
          end
        end

        context "when the security key params are invalid" do
          it "shows an error message and denies login" do
            post "/session/email-login/#{email_token.token}.json",
                 params: {
                   second_factor_token: {
                     signature: "bad_sig",
                     clientData: "bad_clientData",
                     credentialId: "bad_credential_id",
                     authenticatorData: "bad_authenticator_data",
                   },
                   second_factor_method: UserSecondFactor.methods[:security_key],
                 }

            expect(response.status).to eq(200)
            expect(session[:current_user_id]).to eq(nil)
            response_body = response.parsed_body
            expect(response_body["failed"]).to eq("FAILED")
            expect(response_body["error"]).to eq(I18n.t("webauthn.validation.not_found_error"))
          end
        end

        context "when the security key params are valid" do
          it "logs the user in" do
            post "/session/email-login/#{email_token.token}.json",
                 params: {
                   login: user.username,
                   password: "myawesomepassword",
                   second_factor_token: valid_security_key_auth_post_data,
                   second_factor_method: UserSecondFactor.methods[:security_key],
                 }

            expect(response.status).to eq(200)
            expect(response.parsed_body["error"]).not_to be_present
            user.reload

            expect(session[:current_user_id]).to eq(user.id)
            expect(user.user_auth_tokens.count).to eq(1)
          end
        end
      end

      context "when user has security key and totp enabled" do
        let!(:user_security_key) do
          Fabricate(
            :user_security_key,
            user: user,
            credential_id: valid_security_key_data[:credential_id],
            public_key: valid_security_key_data[:public_key],
          )
        end
        let!(:user_second_factor) { Fabricate(:user_second_factor_totp, user: user) }

        it "doesnt allow logging in if the 2fa params are garbled" do
          post "/session/email-login/#{email_token.token}.json",
               params: {
                 second_factor_method: UserSecondFactor.methods[:totp],
                 second_factor_token: "blah",
               }

          expect(response.status).to eq(200)
          expect(session[:current_user_id]).to eq(nil)
          response_body = response.parsed_body
          expect(response_body["error"]).to eq(I18n.t("login.invalid_second_factor_code"))
        end

        it "doesnt allow login if both of the 2fa params are blank" do
          post "/session/email-login/#{email_token.token}.json",
               params: {
                 second_factor_method: UserSecondFactor.methods[:totp],
                 second_factor_token: "",
               }

          expect(response.status).to eq(200)
          expect(session[:current_user_id]).to eq(nil)
          response_body = response.parsed_body
          expect(response_body["error"]).to eq(I18n.t("login.invalid_second_factor_code"))
        end
      end
    end
  end

  describe "logoff support" do
    it "can log off users cleanly" do
      user = Fabricate(:user)
      sign_in(user)

      UserAuthToken.destroy_all

      # we need a route that will call current user
      post "/drafts.json", params: {}
      expect(response.headers["Discourse-Logged-Out"]).to eq("1")
    end
  end

  describe "#become" do
    let!(:user) { Fabricate(:user) }

    it "does not work when in production mode" do
      Rails.env.stubs(:production?).returns(true)
      get "/session/#{user.username}/become.json"

      expect(response.status).to eq(403)
      expect(response.parsed_body["error_type"]).to eq("invalid_access")
      expect(session[:current_user_id]).to be_blank
    end

    it "works in development mode" do
      Rails.env.stubs(:development?).returns(true)
      get "/session/#{user.username}/become.json"
      expect(response).to be_redirect
      expect(session[:current_user_id]).to eq(user.id)
    end
  end

  describe "#sso" do
    before do
      SiteSetting.discourse_connect_url = "http://example.com/discourse_sso"
      SiteSetting.enable_discourse_connect = true
      SiteSetting.discourse_connect_secret = "shjkfdhsfkjh"
    end

    it "redirects correctly" do
      get "/session/sso"
      expect(response.status).to eq(302)
      expect(response.location).to start_with(SiteSetting.discourse_connect_url)
    end
  end

  describe "#sso_login" do
    before do
      @sso_url = "http://example.com/discourse_sso"
      @sso_secret = "shjkfdhsfkjh"

      SiteSetting.discourse_connect_url = @sso_url
      SiteSetting.enable_discourse_connect = true
      SiteSetting.discourse_connect_secret = @sso_secret

      Fabricate(:admin)
    end

    let(:headers) { { host: Discourse.current_hostname } }

    def get_sso(return_path)
      nonce = SecureRandom.hex
      dso = DiscourseConnect.new(secure_session: read_secure_session)
      dso.nonce = nonce
      dso.register_nonce(return_path)

      sso = DiscourseConnectBase.new
      sso.nonce = nonce
      sso.sso_secret = @sso_secret
      sso
    end

    context "when in staff writes only mode" do
      before { Discourse.enable_readonly_mode(Discourse::STAFF_WRITES_ONLY_MODE_KEY) }

      it "allows staff to login" do
        sso = get_sso("/a/")
        sso.external_id = "666"
        sso.email = "bob@bob.com"
        sso.name = "Bob Bobson"
        sso.username = "bob"
        sso.admin = true

        get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers

        logged_on_user = Discourse.current_user_provider.new(request.env).current_user
        expect(logged_on_user).not_to eq(nil)
      end

      it 'doesn\'t allow non-staff to login' do
        sso = get_sso("/a/")
        sso.external_id = "666"
        sso.email = "bob@bob.com"
        sso.name = "Bob Bobson"
        sso.username = "bob"

        get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers

        logged_on_user = Discourse.current_user_provider.new(request.env).current_user
        expect(logged_on_user).to eq(nil)
      end
    end

    it "does not create superfluous auth tokens when already logged in" do
      user = Fabricate(:user)
      sign_in(user)

      sso = get_sso("/")
      sso.email = user.email
      sso.external_id = "abc"
      sso.username = "sam"

      expect do
        get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers
        logged_on_user = Discourse.current_user_provider.new(request.env).current_user
        expect(logged_on_user.id).to eq(user.id)
      end.not_to change { UserAuthToken.count }
    end

    it "will never redirect back to /session/sso path" do
      sso = get_sso("/session/sso?bla=1")
      sso.email = user.email
      sso.external_id = "abc"
      sso.username = "sam"

      get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers
      expect(response).to redirect_to("/")

      sso = get_sso("http://#{Discourse.current_hostname}/session/sso?bla=1")
      sso.email = user.email
      sso.external_id = "abc"
      sso.username = "sam"

      get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers
      expect(response).to redirect_to("/")
    end

    it "can handle invalid sso external ids due to blank" do
      sso = get_sso("/")
      sso.email = "test@test.com"
      sso.external_id = "   "
      sso.username = "sam"

      logger =
        track_log_messages do
          get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers
        end

      expect(logger.warnings.length).to eq(0)
      expect(logger.errors.length).to eq(0)
      expect(logger.fatals.length).to eq(0)
      expect(response.status).to eq(500)
      expect(response.body).to include(I18n.t("discourse_connect.blank_id_error"))
    end

    it "can handle invalid sso email validation errors" do
      SiteSetting.blocked_email_domains = "test.com"
      sso = get_sso("/")
      sso.email = "test@test.com"
      sso.external_id = "123"
      sso.username = "sam"

      logger =
        track_log_messages do
          get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers
        end

      expect(logger.warnings.length).to eq(0)
      expect(logger.errors.length).to eq(0)
      expect(logger.fatals.length).to eq(0)
      expect(response.status).to eq(500)
      expect(response.body).to include(
        I18n.t("discourse_connect.email_error", email: ERB::Util.html_escape("test@test.com")),
      )
    end

    it "can handle invalid sso external ids due to banned word" do
      sso = get_sso("/")
      sso.email = "test@test.com"
      sso.external_id = "nil"
      sso.username = "sam"

      get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers

      expect(response.status).to eq(500)
    end

    it "can take over an account" do
      user = Fabricate(:user, email: "bill@bill.com")

      sso = get_sso("/")
      sso.email = user.email
      sso.external_id = "abc"
      sso.username = "sam"

      get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers

      expect(response).to redirect_to("/")
      logged_on_user = Discourse.current_user_provider.new(request.env).current_user
      expect(logged_on_user.email).to eq(user.email)
      expect(logged_on_user.single_sign_on_record.external_id).to eq("abc")
      expect(logged_on_user.single_sign_on_record.external_username).to eq("sam")

      # we are updating the email ... ensure auto group membership works

      sign_out

      SiteSetting.email_editable = false
      SiteSetting.auth_overrides_email = true

      group = Fabricate(:group, name: :bob, automatic_membership_email_domains: "jane.com")
      sso = get_sso("/")
      sso.email = "hello@jane.com"
      sso.external_id = "abc"

      get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers

      logged_on_user = Discourse.current_user_provider.new(request.env).current_user

      expect(logged_on_user.email).to eq("hello@jane.com")
      expect(group.users.count).to eq(1)
    end

    def sso_for_ip_specs
      sso = get_sso("/a/")
      sso.external_id = "666"
      sso.email = "bob@bob.com"
      sso.name = "Sam Saffron"
      sso.username = "sam"
      sso
    end

    it "respects IP restrictions on create" do
      ScreenedIpAddress.all.destroy_all
      get "/"
      _screened_ip =
        Fabricate(
          :screened_ip_address,
          ip_address: request.remote_ip,
          action_type: ScreenedIpAddress.actions[:block],
        )

      sso = sso_for_ip_specs
      get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers

      logged_on_user = Discourse.current_user_provider.new(request.env).current_user
      expect(logged_on_user).to eq(nil)
    end

    it "respects IP restrictions on login" do
      ScreenedIpAddress.all.destroy_all
      get "/"
      sso = sso_for_ip_specs
      DiscourseConnect.parse(
        sso.payload,
        secure_session: read_secure_session,
      ).lookup_or_create_user(request.remote_ip)

      sso = sso_for_ip_specs
      _screened_ip =
        Fabricate(
          :screened_ip_address,
          ip_address: request.remote_ip,
          action_type: ScreenedIpAddress.actions[:block],
        )

      get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers
      logged_on_user = Discourse.current_user_provider.new(request.env).current_user
      expect(logged_on_user).to be_blank
    end

    it "respects email restrictions" do
      sso = get_sso("/a/")
      sso.external_id = "666"
      sso.email = "bob@bob.com"
      sso.name = "Sam Saffron"
      sso.username = "sam"

      ScreenedEmail.block("bob@bob.com")
      get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers

      logged_on_user = Discourse.current_user_provider.new(request.env).current_user
      expect(logged_on_user).to eq(nil)
    end

    it "allows you to create an admin account" do
      sso = get_sso("/a/")
      sso.external_id = "666"
      sso.email = "bob@bob.com"
      sso.name = "Sam Saffron"
      sso.username = "sam"
      sso.custom_fields["shop_url"] = "http://my_shop.com"
      sso.custom_fields["shop_name"] = "Sam"
      sso.admin = true

      get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers

      logged_on_user = Discourse.current_user_provider.new(request.env).current_user
      expect(logged_on_user.admin).to eq(true)
    end

    it "does not redirect offsite" do
      sso = get_sso("#{Discourse.base_url}//site.com/xyz")
      sso.external_id = "666"
      sso.email = "bob@bob.com"
      sso.name = "Sam Saffron"
      sso.username = "sam"

      get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers
      expect(response).to redirect_to("#{Discourse.base_url}//site.com/xyz")
    end

    it "redirects to a non-relative url" do
      sso = get_sso("#{Discourse.base_url}/b/")
      sso.external_id = "666"
      sso.email = "bob@bob.com"
      sso.name = "Sam Saffron"
      sso.username = "sam"

      get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers
      expect(response).to redirect_to("/b/")
    end

    it "redirects to random url if it is allowed" do
      SiteSetting.discourse_connect_allowed_redirect_domains = "gusundtrout.com|foobar.com"

      sso = get_sso("https://gusundtrout.com")
      sso.external_id = "666"
      sso.email = "bob@bob.com"
      sso.name = "Sam Saffron"
      sso.username = "sam"

      get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers
      expect(response).to redirect_to("https://gusundtrout.com")
    end

    it "allows wildcard character to redirect to any domain" do
      SiteSetting.discourse_connect_allowed_redirect_domains = "*|foo.com"

      sso = get_sso("https://foobar.com")
      sso.external_id = "666"
      sso.email = "bob@bob.com"
      sso.name = "Sam Saffron"
      sso.username = "sam"

      get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers
      expect(response).to redirect_to("https://foobar.com")
    end

    it "does not allow wildcard character in domains" do
      SiteSetting.discourse_connect_allowed_redirect_domains = "*.foobar.com|foobar.com"

      sso = get_sso("https://sub.foobar.com")
      sso.external_id = "666"
      sso.email = "bob@bob.com"
      sso.name = "Sam Saffron"
      sso.username = "sam"

      get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers
      expect(response).to redirect_to("/")
    end

    it "redirects to root if the host of the return_path is different" do
      sso = get_sso("//eviltrout.com")
      sso.external_id = "666"
      sso.email = "bob@bob.com"
      sso.name = "Sam Saffron"
      sso.username = "sam"

      get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers
      expect(response).to redirect_to("/")
    end

    it "redirects to root if the host of the return_path is different" do
      sso = get_sso("http://eviltrout.com")
      sso.external_id = "666"
      sso.email = "bob@bob.com"
      sso.name = "Sam Saffron"
      sso.username = "sam"

      get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers
      expect(response).to redirect_to("/")
    end

    it "creates a user but ignores auto_approve_email_domains site setting when must_approve_users site setting is not enabled" do
      SiteSetting.auto_approve_email_domains = "discourse.com"

      sso = get_sso("/a/")
      sso.external_id = "666"
      sso.email = "sam@discourse.com"
      sso.name = "Sam Saffron"
      sso.username = "sam"

      events =
        DiscourseEvent.track_events do
          get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers

          expect(response).to redirect_to("/a/")
        end

      expect(events.map { |event| event[:event_name] }).to include(
        :user_logged_in,
        :user_first_logged_in,
      )

      logged_on_user = Discourse.current_user_provider.new(request.env).current_user

      # ensure nothing is transient
      logged_on_user = User.find(logged_on_user.id)

      expect(logged_on_user.admin).to eq(false)
      expect(logged_on_user.email).to eq("sam@discourse.com")
      expect(logged_on_user.name).to eq("Sam Saffron")
      expect(logged_on_user.username).to eq("sam")
      expect(logged_on_user.approved).to eq(false)
      expect(logged_on_user.active).to eq(true)

      expect(logged_on_user.single_sign_on_record.external_id).to eq("666")
      expect(logged_on_user.single_sign_on_record.external_username).to eq("sam")
    end

    context "when must_approve_users site setting has been enabled" do
      before { SiteSetting.must_approve_users = true }

      it "creates a user but does not approve when user's email domain does not match a domain in auto_approve_email_domains site settings" do
        SiteSetting.auto_approve_email_domains = "discourse.com"

        sso = get_sso("/a/")
        sso.external_id = "666"
        sso.email = "sam@discourse.org"
        sso.name = "Sam Saffron"
        sso.username = "sam"

        expect do
          get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers

          expect(response.status).to eq(403)
          expect(response.body).to include(I18n.t("discourse_connect.account_not_approved"))
        end.to change { User.count }.by(1)

        logged_on_user = Discourse.current_user_provider.new(request.env).current_user

        expect(logged_on_user).to eq(nil)

        user = User.last

        expect(user.admin).to eq(false)
        expect(user.email).to eq("sam@discourse.org")
        expect(user.name).to eq("Sam Saffron")
        expect(user.username).to eq("sam")
        expect(user.approved).to eq(false)
        expect(user.active).to eq(true)

        expect(user.single_sign_on_record.external_id).to eq("666")
        expect(user.single_sign_on_record.external_username).to eq("sam")
      end

      it "creates and approves a user when user's email domain matches a domain in auto_approve_email_domains site settings" do
        SiteSetting.auto_approve_email_domains = "discourse.com"

        sso = get_sso("/a/")
        sso.external_id = "666"
        sso.email = "sam@discourse.com"
        sso.name = "Sam Saffron"
        sso.username = "sam"

        events =
          DiscourseEvent.track_events do
            get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers

            expect(response).to redirect_to("/a/")
          end

        expect(events.map { |event| event[:event_name] }).to include(
          :user_logged_in,
          :user_first_logged_in,
        )

        logged_on_user = Discourse.current_user_provider.new(request.env).current_user

        # ensure nothing is transient
        logged_on_user = User.find(logged_on_user.id)

        expect(logged_on_user.admin).to eq(false)
        expect(logged_on_user.email).to eq("sam@discourse.com")
        expect(logged_on_user.name).to eq("Sam Saffron")
        expect(logged_on_user.username).to eq("sam")
        expect(logged_on_user.approved).to eq(true)
        expect(logged_on_user.active).to eq(true)

        expect(logged_on_user.single_sign_on_record.external_id).to eq("666")
        expect(logged_on_user.single_sign_on_record.external_username).to eq("sam")
      end
    end

    it "allows you to create an account" do
      group = Fabricate(:group, name: :bob, automatic_membership_email_domains: "bob.com")

      sso = get_sso("/a/")
      sso.external_id = "666"
      sso.email = "bob@bob.com"
      sso.name = "Sam Saffron"
      sso.username = "sam"
      sso.custom_fields["shop_url"] = "http://my_shop.com"
      sso.custom_fields["shop_name"] = "Sam"

      events =
        DiscourseEvent.track_events do
          get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers
        end

      expect(events.map { |event| event[:event_name] }).to include(
        :user_logged_in,
        :user_first_logged_in,
      )

      expect(response).to redirect_to("/a/")

      logged_on_user = Discourse.current_user_provider.new(request.env).current_user

      expect(group.users.where(id: logged_on_user.id).count).to eq(1)

      # ensure nothing is transient
      logged_on_user = User.find(logged_on_user.id)

      expect(logged_on_user.admin).to eq(false)
      expect(logged_on_user.email).to eq("bob@bob.com")
      expect(logged_on_user.name).to eq("Sam Saffron")
      expect(logged_on_user.username).to eq("sam")

      expect(logged_on_user.single_sign_on_record.external_id).to eq("666")
      expect(logged_on_user.single_sign_on_record.external_username).to eq("sam")
      expect(logged_on_user.active).to eq(true)
      expect(logged_on_user.custom_fields["shop_url"]).to eq("http://my_shop.com")
      expect(logged_on_user.custom_fields["shop_name"]).to eq("Sam")
      expect(logged_on_user.custom_fields["bla"]).to eq(nil)
    end

    context "when an invitation is used" do
      let(:invite) { Fabricate(:invite, email: invite_email, invited_by: Fabricate(:admin)) }
      let(:invite_email) { nil }

      def login_with_sso_and_invite(invite_key = invite.invite_key)
        write_secure_session("invite-key", invite_key)
        sso = get_sso("/")
        sso.external_id = "666"
        sso.email = "bob@bob.com"
        sso.name = "Sam Saffron"
        sso.username = "sam"

        get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers
      end

      it "errors if the invite key is invalid" do
        login_with_sso_and_invite("wrong")
        expect(response.status).to eq(400)
        expect(response.body).to include(I18n.t("invite.not_found", base_url: Discourse.base_url))
        expect(invite.reload.redeemed?).to eq(false)
        expect(User.find_by_email("bob@bob.com")).to eq(nil)
      end

      it "errors if the invite has expired" do
        invite.update!(expires_at: 3.days.ago)
        login_with_sso_and_invite
        expect(response.status).to eq(400)
        expect(response.body).to include(I18n.t("invite.expired", base_url: Discourse.base_url))
        expect(invite.reload.redeemed?).to eq(false)
        expect(User.find_by_email("bob@bob.com")).to eq(nil)
      end

      it "errors if the invite has been redeemed already" do
        invite.update!(max_redemptions_allowed: 1, redemption_count: 1)
        login_with_sso_and_invite
        expect(response.status).to eq(400)
        expect(response.body).to include(
          I18n.t(
            "invite.not_found_template",
            site_name: SiteSetting.title,
            base_url: Discourse.base_url,
          ),
        )
        expect(invite.reload.redeemed?).to eq(true)
        expect(User.find_by_email("bob@bob.com")).to eq(nil)
      end

      it "errors if the invite is for a specific email and that email does not match the sso email" do
        invite.update!(email: "someotheremail@dave.com")
        login_with_sso_and_invite
        expect(response.status).to eq(400)
        expect(response.body).to include(
          I18n.t("invite.not_matching_email", base_url: Discourse.base_url),
        )
        expect(invite.reload.redeemed?).to eq(false)
        expect(User.find_by_email("bob@bob.com")).to eq(nil)
      end

      it "allows you to create an account and redeems the invite successfully, clearing the invite-key session" do
        login_with_sso_and_invite

        expect(response.status).to eq(302)
        expect(response).to redirect_to("/")
        expect(invite.reload.redeemed?).to eq(true)

        user = User.find_by_email("bob@bob.com")
        expect(user.active).to eq(true)
        expect(session[:current_user_id]).to eq(user.id)
        expect(read_secure_session["invite-key"]).to eq(nil)
      end

      it "creates the user account and redeems the invite but does not approve the user if must_approve_users is enabled" do
        SiteSetting.must_approve_users = true

        login_with_sso_and_invite

        expect(response.status).to eq(403)
        expect(response.body).to include(I18n.t("discourse_connect.account_not_approved"))
        expect(invite.reload.redeemed?).to eq(true)

        user = User.find_by_email("bob@bob.com")
        expect(user.active).to eq(true)
        expect(user.approved).to eq(false)
      end

      it "redirects to the topic associated to the invite" do
        topic_invite = TopicInvite.create!(invite: invite, topic: Fabricate(:topic))
        login_with_sso_and_invite

        expect(response.status).to eq(302)
        expect(response).to redirect_to(topic_invite.topic.relative_url)
      end

      it "adds the user to the appropriate invite groups" do
        invited_group = InvitedGroup.create!(invite: invite, group: Fabricate(:group))
        login_with_sso_and_invite

        expect(invite.reload.redeemed?).to eq(true)

        user = User.find_by_email("bob@bob.com")
        expect(GroupUser.exists?(user: user, group: invited_group.group)).to eq(true)
      end
    end

    context "when sso emails are not trusted" do
      context "if you have not activated your account" do
        it "does not log you in" do
          sso = get_sso("/a/")
          sso.external_id = "666"
          sso.email = "bob@bob.com"
          sso.name = "Sam Saffron"
          sso.username = "sam"
          sso.require_activation = true

          get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers

          logged_on_user = Discourse.current_user_provider.new(request.env).current_user
          expect(logged_on_user).to eq(nil)
        end

        it "sends an activation email" do
          sso = get_sso("/a/")
          sso.external_id = "666"
          sso.email = "bob@bob.com"
          sso.name = "Sam Saffron"
          sso.username = "sam"
          sso.require_activation = true

          get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers
          expect(Jobs::CriticalUserEmail.jobs.size).to eq(1)
        end
      end

      context "if you have activated your account" do
        it "allows you to log in" do
          sso = get_sso("/hello/world")
          sso.external_id = "997"
          sso.sso_url = "http://somewhere.over.com/sso_login"
          sso.require_activation = true

          user = Fabricate(:user)
          user.create_single_sign_on_record(external_id: "997", last_payload: "")
          user.stubs(:active?).returns(true)

          get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers

          logged_on_user = Discourse.current_user_provider.new(request.env).current_user
          expect(user.id).to eq(logged_on_user.id)
        end
      end
    end

    it "allows login to existing account with valid nonce" do
      sso = get_sso("/hello/world")
      sso.external_id = "997"
      sso.sso_url = "http://somewhere.over.com/sso_login"

      user = Fabricate(:user)
      user.create_single_sign_on_record(external_id: "997", last_payload: "")

      get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers

      user.single_sign_on_record.reload
      expect(user.single_sign_on_record.last_payload).to eq(sso.unsigned_payload)

      expect(response).to redirect_to("/hello/world")
      logged_on_user = Discourse.current_user_provider.new(request.env).current_user

      expect(user.id).to eq(logged_on_user.id)

      # nonce is bad now
      get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers
      expect(response.status).to eq(419)
    end

    it "associates the nonce with the current session" do
      sso = get_sso("/hello/world")
      sso.external_id = "997"
      sso.sso_url = "http://somewhere.over.com/sso_login"

      user = Fabricate(:user)
      user.create_single_sign_on_record(external_id: "997", last_payload: "")

      # Establish a fresh session
      cookies.to_hash.keys.each { |k| cookies.delete(k) }

      get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers
      expect(response.status).to eq(419)
    end

    context "when sso provider is enabled" do
      before do
        SiteSetting.enable_discourse_connect_provider = true
        SiteSetting.discourse_connect_provider_secrets = %w[
          *|secret,forAll
          *.rainbow|wrongSecretForOverRainbow
          www.random.site|secretForRandomSite
          somewhere.over.rainbow|secretForOverRainbow
        ].join("\n")
      end

      it "doesn't break" do
        sso = get_sso("/hello/world")
        sso.external_id = "997"
        sso.sso_url = "http://somewhere.over.com/sso_login"
        sso.return_sso_url = "http://someurl.com"

        user = Fabricate(:user)
        user.create_single_sign_on_record(external_id: "997", last_payload: "")

        get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers

        user.single_sign_on_record.reload
        expect(user.single_sign_on_record.last_payload).to eq(sso.unsigned_payload)

        expect(response).to redirect_to("/hello/world")
        logged_on_user = Discourse.current_user_provider.new(request.env).current_user

        expect(user.id).to eq(logged_on_user.id)
      end
    end

    it "returns the correct error code for invalid payload" do
      sso = get_sso("/hello/world")
      sso.external_id = "997"
      sso.sso_url = "http://somewhere.over.com/sso_login"

      params = Rack::Utils.parse_query(sso.payload)
      params["sso"] = "#{params["sso"]}%3C"
      params["sig"] = sso.sign(params["sso"])

      get "/session/sso_login", params: params, headers: headers
      expect(response.status).to eq(422)
      expect(response.body).to include(I18n.t("discourse_connect.payload_parse_error"))

      logged_on_user = Discourse.current_user_provider.new(request.env).current_user
      expect(logged_on_user).to eq(nil)
    end

    it "returns the correct error code for invalid signature" do
      sso = get_sso("/hello/world")
      sso.external_id = "997"
      sso.sso_url = "http://somewhere.over.com/sso_login"

      correct_params = Rack::Utils.parse_query(sso.payload)
      get "/session/sso_login",
          params: correct_params.merge(sig: "thisisnotthesigyouarelookingfor"),
          headers: headers
      expect(response.status).to eq(422)
      expect(response.body).to include(I18n.t("discourse_connect.signature_error"))
      expect(response.body).not_to include(correct_params["sig"]) # Check we didn't send the real sig back to the client
      logged_on_user = Discourse.current_user_provider.new(request.env).current_user
      expect(logged_on_user).to eq(nil)

      correct_params = Rack::Utils.parse_query(sso.payload)
      get "/session/sso_login",
          params: correct_params.merge(sig: "thisisasignaturewith@special!characters"),
          headers: headers
      expect(response.status).to eq(422)
      expect(response.body).not_to include(correct_params["sig"]) # Check we didn't send the real sig back to the client
      logged_on_user = Discourse.current_user_provider.new(request.env).current_user
      expect(logged_on_user).to eq(nil)
    end

    describe "local attribute override from SSO payload" do
      before do
        SiteSetting.email_editable = false
        SiteSetting.auth_overrides_email = true
        SiteSetting.auth_overrides_username = true
        SiteSetting.auth_overrides_name = true

        @user = Fabricate(:user)

        @sso = get_sso("/hello/world")
        @sso.external_id = "997"

        @reversed_username = @user.username.reverse
        @sso.username = @reversed_username
        @sso.email = "#{@reversed_username}@garbage.org"
        @reversed_name = @user.name.reverse
        @sso.name = @reversed_name

        @suggested_username = UserNameSuggester.suggest(@sso.username || @sso.name || @sso.email)
        @suggested_name = User.suggest_name(@sso.name || @sso.username || @sso.email)
        @user.create_single_sign_on_record(external_id: "997", last_payload: "")
      end

      it "stores the external attributes" do
        get "/session/sso_login", params: Rack::Utils.parse_query(@sso.payload), headers: headers
        @user.single_sign_on_record.reload
        expect(@user.single_sign_on_record.external_username).to eq(@sso.username)
        expect(@user.single_sign_on_record.external_email).to eq(@sso.email)
        expect(@user.single_sign_on_record.external_name).to eq(@sso.name)
      end

      it "overrides attributes" do
        get "/session/sso_login", params: Rack::Utils.parse_query(@sso.payload), headers: headers

        logged_on_user = Discourse.current_user_provider.new(request.env).current_user
        expect(logged_on_user.username).to eq(@suggested_username)
        expect(logged_on_user.email).to eq("#{@reversed_username}@garbage.org")
        expect(logged_on_user.name).to eq(@sso.name)
      end

      it "does not change matching attributes for an existing account" do
        @sso.username = @user.username
        @sso.name = @user.name
        @sso.email = @user.email

        get "/session/sso_login", params: Rack::Utils.parse_query(@sso.payload), headers: headers

        logged_on_user = Discourse.current_user_provider.new(request.env).current_user
        expect(logged_on_user.username).to eq(@user.username)
        expect(logged_on_user.name).to eq(@user.name)
        expect(logged_on_user.email).to eq(@user.email)
      end
    end

    context "when in readonly mode" do
      before { Discourse.enable_readonly_mode }

      it "disallows requests" do
        get "/session/sso_login"

        expect(response.status).to eq(503)
      end
    end
  end

  describe "#sso_provider" do
    let(:headers) { { host: Discourse.current_hostname } }
    let(:logo_fixture) { "http://#{Discourse.current_hostname}/uploads/logo.png" }
    fab!(:user) { Fabricate(:user, password: "myfrogs123ADMIN", active: true, admin: true) }

    before do
      stub_request(:any, %r{#{Discourse.current_hostname}/uploads}).to_return(
        status: 200,
        body: lambda { |request| file_from_fixtures("logo.png") },
      )

      SiteSetting.enable_discourse_connect_provider = true
      SiteSetting.enable_discourse_connect = false
      SiteSetting.enable_local_logins = true
      SiteSetting.discourse_connect_provider_secrets = %w[
        *|secret,forAll
        *.rainbow|wrongSecretForOverRainbow
        www.random.site|secretForRandomSite
        somewhere.over.rainbow|oldSecretForOverRainbow
        somewhere.over.rainbow|secretForOverRainbow
        somewhere.over.rainbow|newSecretForOverRainbow
      ].join("\n")

      @sso = DiscourseConnectProvider.new
      @sso.nonce = "mynonce"
      @sso.return_sso_url = "http://somewhere.over.rainbow/sso"

      @user = user
      group = Fabricate(:group)
      group.add(@user)

      @user.create_user_avatar!
      UserAvatar.import_url_for_user(logo_fixture, @user)
      UserProfile.import_url_for_user(logo_fixture, @user, is_card_background: false)
      UserProfile.import_url_for_user(logo_fixture, @user, is_card_background: true)

      @user.reload
      @user.user_avatar.reload
      @user.user_profile.reload
      EmailToken.update_all(confirmed: true)
    end

    describe "can act as an SSO provider" do
      it "successfully logs in and redirects user to return_sso_url when the user is not logged in" do
        get "/session/sso_provider",
            params: Rack::Utils.parse_query(@sso.payload("secretForOverRainbow"))

        expect(response).to redirect_to("/login")

        post "/session.json",
             params: {
               login: @user.username,
               password: "myfrogs123ADMIN",
             },
             xhr: true,
             headers: headers

        location = response.cookies["sso_destination_url"]
        # javascript code will handle redirection of user to return_sso_url
        expect(location).to match(%r{^http://somewhere.over.rainbow/sso})

        payload = location.split("?")[1]
        sso2 = DiscourseConnectProvider.parse(payload)

        expect(sso2.email).to eq(@user.email)
        expect(sso2.name).to eq(@user.name)
        expect(sso2.username).to eq(@user.username)
        expect(sso2.external_id).to eq(@user.id.to_s)
        expect(sso2.admin).to eq(true)
        expect(sso2.moderator).to eq(false)
        expect(sso2.groups).to eq(@user.groups.pluck(:name).join(","))

        expect(sso2.avatar_url.blank?).to_not eq(true)
        expect(sso2.profile_background_url.blank?).to_not eq(true)
        expect(sso2.card_background_url.blank?).to_not eq(true)

        expect(sso2.avatar_url).to start_with(Discourse.base_url)
        expect(sso2.profile_background_url).to start_with(Discourse.base_url)
        expect(sso2.card_background_url).to start_with(Discourse.base_url)
        expect(sso2.confirmed_2fa).to eq(nil)
        expect(sso2.no_2fa_methods).to eq(nil)
      end

      it "correctly logs in for secondary domain secrets" do
        sign_in @user

        get "/session/sso_provider",
            params: Rack::Utils.parse_query(@sso.payload("newSecretForOverRainbow"))
        expect(response.status).to eq(302)
        redirect_uri = URI.parse(response.location)
        expect(redirect_uri.host).to eq("somewhere.over.rainbow")
        redirect_query = CGI.parse(redirect_uri.query)
        expected_sig =
          DiscourseConnectBase.sign(redirect_query["sso"][0], "newSecretForOverRainbow")
        expect(redirect_query["sig"][0]).to eq(expected_sig)

        get "/session/sso_provider",
            params: Rack::Utils.parse_query(@sso.payload("oldSecretForOverRainbow"))
        expect(response.status).to eq(302)
        redirect_uri = URI.parse(response.location)
        expect(redirect_uri.host).to eq("somewhere.over.rainbow")
        redirect_query = CGI.parse(redirect_uri.query)
        expected_sig =
          DiscourseConnectBase.sign(redirect_query["sso"][0], "oldSecretForOverRainbow")
        expect(redirect_query["sig"][0]).to eq(expected_sig)
      end

      it "fails to log in if secret is wrong" do
        get "/session/sso_provider",
            params: Rack::Utils.parse_query(@sso.payload("secretForRandomSite"))
        expect(response.status).to eq(422)
      end

      it "fails with a nice error message if secret is blank" do
        SiteSetting.discourse_connect_provider_secrets = ""
        sso = DiscourseConnectProvider.new
        sso.nonce = "mynonce"
        sso.return_sso_url = "http://website.without.secret.com/sso"
        get "/session/sso_provider", params: Rack::Utils.parse_query(sso.payload("aasdasdasd"))
        expect(response.status).to eq(400)
        expect(response.body).to eq(I18n.t("discourse_connect.missing_secret"))
      end

      it "returns a 422 if no return_sso_url" do
        SiteSetting.discourse_connect_provider_secrets = "abcdefghij"
        get "/session/sso_provider?sso=asdf&sig=abcdefghij"
        expect(response.status).to eq(422)
      end

      it "successfully redirects user to return_sso_url when the user is logged in" do
        sign_in(@user)

        get "/session/sso_provider",
            params: Rack::Utils.parse_query(@sso.payload("secretForOverRainbow"))

        location = response.header["Location"]
        expect(location).to match(%r{^http://somewhere.over.rainbow/sso})

        payload = location.split("?")[1]
        sso2 = DiscourseConnectProvider.parse(payload)

        expect(sso2.email).to eq(@user.email)
        expect(sso2.name).to eq(@user.name)
        expect(sso2.username).to eq(@user.username)
        expect(sso2.external_id).to eq(@user.id.to_s)
        expect(sso2.admin).to eq(true)
        expect(sso2.moderator).to eq(false)
        expect(sso2.groups).to eq(@user.groups.pluck(:name).join(","))

        expect(sso2.avatar_url.blank?).to_not eq(true)
        expect(sso2.profile_background_url.blank?).to_not eq(true)
        expect(sso2.card_background_url.blank?).to_not eq(true)

        expect(sso2.avatar_url).to start_with(Discourse.base_url)
        expect(sso2.profile_background_url).to start_with(Discourse.base_url)
        expect(sso2.card_background_url).to start_with(Discourse.base_url)
        expect(sso2.confirmed_2fa).to eq(nil)
        expect(sso2.no_2fa_methods).to eq(nil)
      end

      it "fails with a nice error message if `prompt` parameter has an invalid value" do
        @sso.prompt = "xyzpdq"

        get "/session/sso_provider",
            params: Rack::Utils.parse_query(@sso.payload("secretForOverRainbow"))

        expect(response.status).to eq(400)
        expect(response.body).to eq(
          I18n.t("discourse_connect.invalid_parameter_value", param: "prompt"),
        )
      end

      it "redirects browser to return_sso_url with auth failure when prompt=none is requested and the user is not logged in" do
        @sso.prompt = "none"

        get "/session/sso_provider",
            params: Rack::Utils.parse_query(@sso.payload("secretForOverRainbow"))

        location = response.header["Location"]
        expect(location).to match(%r{^http://somewhere.over.rainbow/sso})

        payload = location.split("?")[1]
        sso2 = DiscourseConnectProvider.parse(payload)

        expect(sso2.failed).to eq(true)

        expect(sso2.email).to eq(nil)
        expect(sso2.name).to eq(nil)
        expect(sso2.username).to eq(nil)
        expect(sso2.external_id).to eq(nil)
        expect(sso2.admin).to eq(nil)
        expect(sso2.moderator).to eq(nil)
        expect(sso2.groups).to eq(nil)

        expect(sso2.avatar_url).to eq(nil)
        expect(sso2.profile_background_url).to eq(nil)
        expect(sso2.card_background_url).to eq(nil)
        expect(sso2.confirmed_2fa).to eq(nil)
        expect(sso2.no_2fa_methods).to eq(nil)
      end

      it "handles non local content correctly" do
        SiteSetting.avatar_sizes = "100|49"
        setup_s3
        SiteSetting.s3_cdn_url = "http://cdn.com"

        stub_request(:any, /s3-upload-bucket.s3.dualstack.us-west-1.amazonaws.com/).to_return(
          status: 200,
          body: "",
          headers: {
            referer: "fgdfds",
          },
        )

        @user.create_user_avatar!
        upload =
          Fabricate(
            :upload,
            url: "//s3-upload-bucket.s3.dualstack.us-west-1.amazonaws.com/something",
          )

        Fabricate(
          :optimized_image,
          sha1: SecureRandom.hex << "A" * 8,
          upload: upload,
          width: 98,
          height: 98,
          url: "//s3-upload-bucket.s3.amazonaws.com/something/else",
        )

        @user.update_columns(uploaded_avatar_id: upload.id)

        upload1 = Fabricate(:upload_s3)
        upload2 = Fabricate(:upload_s3)

        @user.user_profile.update!(
          profile_background_upload: upload1,
          card_background_upload: upload2,
        )

        @user.reload
        @user.user_avatar.reload
        @user.user_profile.reload

        sign_in(@user)

        stub_request(:get, "http://cdn.com/something/else").to_return(
          body: lambda { |request| File.new(Rails.root + "spec/fixtures/images/logo.png") },
        )

        get "/session/sso_provider",
            params: Rack::Utils.parse_query(@sso.payload("secretForOverRainbow"))

        location = response.header["Location"]
        # javascript code will handle redirection of user to return_sso_url
        expect(location).to match(%r{^http://somewhere.over.rainbow/sso})

        payload = location.split("?")[1]
        sso2 = DiscourseConnectProvider.parse(payload)

        expect(sso2.avatar_url.blank?).to_not eq(true)
        expect(sso2.profile_background_url.blank?).to_not eq(true)
        expect(sso2.card_background_url.blank?).to_not eq(true)

        expect(sso2.avatar_url).to start_with("#{SiteSetting.s3_cdn_url}/original")
        expect(sso2.profile_background_url).to start_with(SiteSetting.s3_cdn_url)
        expect(sso2.card_background_url).to start_with(SiteSetting.s3_cdn_url)
        expect(sso2.confirmed_2fa).to eq(nil)
        expect(sso2.no_2fa_methods).to eq(nil)
      end

      it "successfully logs out and redirects user to return_sso_url when the user is logged in" do
        sign_in(@user)

        @sso.logout = true
        get "/session/sso_provider",
            params: Rack::Utils.parse_query(@sso.payload("secretForOverRainbow"))

        location = response.header["Location"]
        expect(location).to match(%r{^http://somewhere.over.rainbow/sso$})

        expect(response.status).to eq(302)
        expect(session[:current_user_id]).to be_blank
        expect(response.cookies["_t"]).to be_blank
      end

      it "successfully logs out and redirects user to return_sso_url when the user is not logged in" do
        @sso.logout = true
        get "/session/sso_provider",
            params: Rack::Utils.parse_query(@sso.payload("secretForOverRainbow"))

        location = response.header["Location"]
        expect(location).to match(%r{^http://somewhere.over.rainbow/sso$})

        expect(response.status).to eq(302)
        expect(session[:current_user_id]).to be_blank
        expect(response.cookies["_t"]).to be_blank
      end
    end

    describe "can act as a 2FA provider" do
      fab!(:user_totp) { Fabricate(:user_second_factor_totp, user: user) }
      before { @sso.require_2fa = true }

      it "requires the user to confirm 2FA before they are redirected to the SSO return URL" do
        sign_in(user)
        get "/session/sso_provider",
            params: Rack::Utils.parse_query(@sso.payload("secretForOverRainbow"))
        uri = URI(response.location)
        expect(uri.hostname).to eq(Discourse.current_hostname)
        expect(uri.path).to eq("/session/2fa")
        nonce = uri.query.match(/\Anonce=([A-Za-z0-9]{32})\Z/)[1]
        expect(nonce).to be_present

        # attempt no. 1 to bypass 2fa
        get "/session/sso_provider", params: { second_factor_nonce: nonce }
        expect(response.status).to eq(401)
        expect(response.parsed_body["error"]).to eq(
          I18n.t("second_factor_auth.challenge_not_completed"),
        )

        # attempt no. 2 to bypass 2fa
        get "/session/sso_provider",
            params: { second_factor_nonce: nonce }.merge(
              Rack::Utils.parse_query(@sso.payload("secretForOverRainbow")),
            )
        expect(response.status).to eq(401)
        expect(response.parsed_body["error"]).to eq(
          I18n.t("second_factor_auth.challenge_not_completed"),
        )

        # confirm 2fa
        post "/session/2fa.json",
             params: {
               nonce: nonce,
               second_factor_token: ROTP::TOTP.new(user_totp.data).now,
               second_factor_method: UserSecondFactor.methods[:totp],
             }
        expect(response.status).to eq(200)
        expect(response.parsed_body["ok"]).to eq(true)
        expect(response.parsed_body["callback_method"]).to eq("GET")
        expect(response.parsed_body["callback_path"]).to eq("/session/sso_provider")
        expect(response.parsed_body["redirect_url"]).to be_blank

        get "/session/sso_provider", params: { second_factor_nonce: nonce }
        expect(response.status).to eq(200)
        expect(response.parsed_body["success"]).to eq("OK")
        redirect_url = response.parsed_body["redirect_url"]
        expect(redirect_url).to start_with("http://somewhere.over.rainbow/sso?sso=")
        sso = DiscourseConnectProvider.parse(URI(redirect_url).query)
        expect(sso.confirmed_2fa).to eq(true)
        expect(sso.no_2fa_methods).to eq(nil)
        expect(sso.username).to eq(user.username)
        expect(sso.email).to eq(user.email)
      end

      it "doesn't accept backup codes" do
        backup_codes = user.generate_backup_codes
        sign_in(user)
        get "/session/sso_provider",
            params: Rack::Utils.parse_query(@sso.payload("secretForOverRainbow"))
        uri = URI(response.location)
        expect(uri.hostname).to eq(Discourse.current_hostname)
        expect(uri.path).to eq("/session/2fa")
        nonce = uri.query.match(/\Anonce=([A-Za-z0-9]{32})\Z/)[1]
        expect(nonce).to be_present

        post "/session/2fa.json",
             params: {
               nonce: nonce,
               second_factor_token: backup_codes.sample,
               second_factor_method: UserSecondFactor.methods[:backup_codes],
             }
        expect(response.status).to eq(403)
        get "/session/sso_provider", params: { second_factor_nonce: nonce }
        expect(response.status).to eq(401)
        expect(response.parsed_body["error"]).to eq(
          I18n.t("second_factor_auth.challenge_not_completed"),
        )
      end

      context "when the user has no 2fa methods" do
        before do
          user_totp.destroy!
          user.reload
        end

        it "redirects the user back to the SSO return url and indicates in the payload that they do not have 2fa methods" do
          sign_in(user)
          get "/session/sso_provider",
              params: Rack::Utils.parse_query(@sso.payload("secretForOverRainbow"))

          expect(response.status).to eq(302)
          redirect_url = response.location
          expect(redirect_url).to start_with("http://somewhere.over.rainbow/sso?sso=")
          sso = DiscourseConnectProvider.parse(URI(redirect_url).query)
          expect(sso.confirmed_2fa).to eq(nil)
          expect(sso.no_2fa_methods).to eq(true)
          expect(sso.username).to eq(user.username)
          expect(sso.email).to eq(user.email)
        end
      end

      context "when there is no logged in user" do
        it "redirects the user to login first" do
          get "/session/sso_provider",
              params: Rack::Utils.parse_query(@sso.payload("secretForOverRainbow"))
          expect(response.status).to eq(302)
          expect(response.location).to eq("http://#{Discourse.current_hostname}/login")
        end

        it "doesn't make the user confirm 2fa twice if they've just logged in and confirmed 2fa while doing so" do
          get "/session/sso_provider",
              params: Rack::Utils.parse_query(@sso.payload("secretForOverRainbow"))

          post "/session.json",
               params: {
                 login: user.username,
                 password: "myfrogs123ADMIN",
                 second_factor_token: ROTP::TOTP.new(user_totp.data).now,
                 second_factor_method: UserSecondFactor.methods[:totp],
               },
               xhr: true,
               headers: headers
          expect(response.status).to eq(200)
          # the frontend will take care of actually redirecting the user
          redirect_url = response.cookies["sso_destination_url"]
          expect(redirect_url).to start_with("http://somewhere.over.rainbow/sso?sso=")
          sso = DiscourseConnectProvider.parse(URI(redirect_url).query)
          expect(sso.confirmed_2fa).to eq(true)
          expect(sso.no_2fa_methods).to eq(nil)
          expect(sso.username).to eq(user.username)
          expect(sso.email).to eq(user.email)
        end

        it "doesn't indicate the user has confirmed 2fa after they've logged in if they have no 2fa methods" do
          user_totp.destroy!
          user.reload
          get "/session/sso_provider",
              params: Rack::Utils.parse_query(@sso.payload("secretForOverRainbow"))

          post "/session.json",
               params: {
                 login: user.username,
                 password: "myfrogs123ADMIN",
               },
               xhr: true,
               headers: headers
          redirect_url = response.cookies["sso_destination_url"]
          expect(redirect_url).to start_with("http://somewhere.over.rainbow/sso?sso=")
          sso = DiscourseConnectProvider.parse(URI(redirect_url).query)
          expect(sso.confirmed_2fa).to eq(nil)
          expect(sso.no_2fa_methods).to eq(true)
          expect(sso.username).to eq(user.username)
          expect(sso.email).to eq(user.email)
        end
      end
    end
  end

  describe "#create" do
    context "when read only mode" do
      before do
        Discourse.enable_readonly_mode
        EmailToken.confirm(email_token.token)
        EmailToken.confirm(admin_email_token.token)
      end

      it "prevents login by regular users" do
        post "/session.json", params: { login: user.username, password: "myawesomepassword" }
        expect(response.status).not_to eq(200)
      end

      it "prevents login by admins" do
        post "/session.json", params: { login: admin.username, password: "myawesomepassword" }
        expect(response.status).not_to eq(200)
      end
    end

    context "when in staff writes only mode" do
      before do
        Discourse.enable_readonly_mode(Discourse::STAFF_WRITES_ONLY_MODE_KEY)
        EmailToken.confirm(email_token.token)
        EmailToken.confirm(admin_email_token.token)
      end

      it "allows admin login" do
        post "/session.json", params: { login: admin.username, password: "myawesomepassword" }
        expect(response.status).to eq(200)
        expect(response.parsed_body["error"]).not_to be_present
      end

      it "prevents login by regular users" do
        post "/session.json", params: { login: user.username, password: "myawesomepassword" }
        expect(response.status).not_to eq(200)
      end
    end

    context "when local login is disabled" do
      before do
        SiteSetting.enable_local_logins = false

        post "/session.json", params: { login: user.username, password: "myawesomepassword" }
      end
      it_behaves_like "failed to continue local login"
    end

    context "when SSO is enabled" do
      before do
        SiteSetting.discourse_connect_url = "https://www.example.com/sso"
        SiteSetting.enable_discourse_connect = true

        post "/session.json", params: { login: user.username, password: "myawesomepassword" }
      end
      it_behaves_like "failed to continue local login"
    end

    context "when local login via email is disabled" do
      before do
        SiteSetting.enable_local_logins_via_email = false
        EmailToken.confirm(email_token.token)
      end
      it "doesnt matter, logs in correctly" do
        post "/session.json", params: { login: user.username, password: "myawesomepassword" }
        expect(response.status).to eq(200)
        expect(response.parsed_body["error"]).not_to be_present
      end
    end

    context "when email is confirmed" do
      before { EmailToken.confirm(email_token.token) }

      it "raises an error when the login isn't present" do
        post "/session.json"
        expect(response.status).to eq(400)
      end

      describe "invalid password" do
        it "should return an error with an invalid password" do
          post "/session.json", params: { login: user.username, password: "sssss" }

          expect(response.status).to eq(200)
          expect(response.parsed_body["error"]).to eq(
            I18n.t("login.incorrect_username_email_or_password"),
          )
        end

        it "should return an error with an invalid password if too long" do
          User.any_instance.expects(:confirm_password?).never
          post "/session.json",
               params: {
                 login: user.username,
                 password: ("s" * (User.max_password_length + 1)),
               }

          expect(response.status).to eq(200)
          expect(response.parsed_body["error"]).to eq(
            I18n.t("login.incorrect_username_email_or_password"),
          )
        end
      end

      describe "suspended user" do
        it "should return an error" do
          user.suspended_till = 2.days.from_now
          user.suspended_at = Time.now
          user.save!
          StaffActionLogger.new(user).log_user_suspend(user, "<strike>banned</strike>")

          post "/session.json", params: { login: user.username, password: "myawesomepassword" }

          expected_message =
            I18n.t(
              "login.suspended_with_reason",
              date: I18n.l(user.suspended_till, format: :date_only),
              reason: Rack::Utils.escape_html(user.suspend_reason),
            )
          expect(response.status).to eq(200)
          expect(response.parsed_body["error"]).to eq(expected_message)
        end

        it "when suspended forever should return an error without suspended till date" do
          user.suspended_till = 101.years.from_now
          user.suspended_at = Time.now
          user.save!
          StaffActionLogger.new(user).log_user_suspend(user, "<strike>banned</strike>")

          post "/session.json", params: { login: user.username, password: "myawesomepassword" }

          expected_message =
            I18n.t(
              "login.suspended_with_reason_forever",
              reason: Rack::Utils.escape_html(user.suspend_reason),
            )
          expect(response.parsed_body["error"]).to eq(expected_message)
        end
      end

      describe "deactivated user" do
        it "should return an error" do
          user.active = false
          user.save!

          post "/session.json", params: { login: user.username, password: "myawesomepassword" }

          expect(response.status).to eq(200)
          expect(response.parsed_body["error"]).to eq(I18n.t("login.not_activated"))
        end
      end

      describe "success by username and password" do
        it "logs in correctly" do
          events =
            DiscourseEvent.track_events do
              post "/session.json", params: { login: user.username, password: "myawesomepassword" }
            end

          expect(response.status).to eq(200)
          expect(response.parsed_body["error"]).not_to be_present
          expect(events.map { |event| event[:event_name] }).to contain_exactly(
            :user_logged_in,
            :user_first_logged_in,
          )

          user.reload

          expect(session[:current_user_id]).to eq(user.id)
          expect(user.user_auth_tokens.count).to eq(1)
          expect(user.user_auth_tokens.last.authenticated_with_oauth).to be false
          unhashed_token = decrypt_auth_cookie(cookies[:_t])[:token]
          expect(UserAuthToken.hash_token(unhashed_token)).to eq(
            user.user_auth_tokens.first.auth_token,
          )
        end

        context "when timezone param is provided" do
          it "sets the user_option timezone for the user" do
            post "/session.json",
                 params: {
                   login: user.username,
                   password: "myawesomepassword",
                   timezone: "Australia/Melbourne",
                 }
            expect(response.status).to eq(200)
            expect(response.parsed_body["error"]).not_to be_present
            expect(user.reload.user_option.timezone).to eq("Australia/Melbourne")
          end
        end
      end

      describe "when user's password has been marked as expired" do
        before { RateLimiter.enable }

        it "should return an error response code with the right error message" do
          UserPasswordExpirer.expire_user_password(user)
          post "/session.json", params: { login: user.username, password: "myawesomepassword" }

          expect(response.status).to eq(200)
          expect(response.parsed_body["error"]).to eq("expired")
          expect(response.parsed_body["reason"]).to eq("expired")
          expect(session[:current_user_id]).to eq(nil)
        end
      end

      context "when a user has security key-only 2FA login" do
        let!(:user_security_key) do
          Fabricate(
            :user_security_key,
            user: user,
            credential_id: valid_security_key_data[:credential_id],
            public_key: valid_security_key_data[:public_key],
          )
        end

        before do
          simulate_localhost_webauthn_challenge
          DiscourseWebauthn.stubs(:origin).returns("http://localhost:3000")

          # store challenge in secure session by failing login once
          post "/session.json", params: { login: user.username, password: "myawesomepassword" }
        end

        context "when the security key params are blank and a random second factor token is provided" do
          it "shows an error message and denies login" do
            post "/session.json",
                 params: {
                   login: user.username,
                   password: "myawesomepassword",
                   second_factor_token: "99999999",
                   second_factor_method: UserSecondFactor.methods[:security_key],
                 }

            expect(response.status).to eq(200)
            expect(session[:current_user_id]).to eq(nil)
            response_body = response.parsed_body
            expect(response_body["failed"]).to eq("FAILED")
            expect(response_body["error"]).to eq(
              I18n.t("webauthn.validation.malformed_public_key_credential_error"),
            )
          end
        end

        context "when the security key params are invalid" do
          it "shows an error message and denies login" do
            post "/session.json",
                 params: {
                   login: user.username,
                   password: "myawesomepassword",
                   second_factor_token: {
                     signature: "bad_sig",
                     clientData: "bad_clientData",
                     credentialId: "bad_credential_id",
                     authenticatorData: "bad_authenticator_data",
                   },
                   second_factor_method: UserSecondFactor.methods[:security_key],
                 }

            expect(response.status).to eq(200)
            expect(session[:current_user_id]).to eq(nil)
            response_body = response.parsed_body
            expect(response_body["failed"]).to eq("FAILED")
            expect(response_body["error"]).to eq(I18n.t("webauthn.validation.not_found_error"))
          end
        end

        context "when the security key params are valid" do
          it "logs the user in" do
            post "/session.json",
                 params: {
                   login: user.username,
                   password: "myawesomepassword",
                   second_factor_token: valid_security_key_auth_post_data,
                   second_factor_method: UserSecondFactor.methods[:security_key],
                 }

            expect(response.status).to eq(200)
            expect(response.parsed_body["error"]).not_to be_present
            user.reload

            expect(session[:current_user_id]).to eq(user.id)
            expect(user.user_auth_tokens.count).to eq(1)
          end
        end

        context "when the security key is disabled in the background by the user and TOTP is enabled" do
          before do
            user_security_key.destroy!
            Fabricate(:user_second_factor_totp, user: user)
          end

          it "shows an error message and denies login" do
            post "/session.json",
                 params: {
                   login: user.username,
                   password: "myawesomepassword",
                   second_factor_token: valid_security_key_auth_post_data,
                   second_factor_method: UserSecondFactor.methods[:security_key],
                 }

            expect(response.status).to eq(200)
            expect(session[:current_user_id]).to eq(nil)
            response_body = response.parsed_body
            expect(response_body["failed"]).to eq("FAILED")
            expect(response.parsed_body["error"]).to eq(
              I18n.t("login.not_enabled_second_factor_method"),
            )
          end
        end
      end

      context "when user has TOTP-only 2FA login" do
        let!(:user_second_factor) { Fabricate(:user_second_factor_totp, user: user) }
        let!(:user_second_factor_backup) { Fabricate(:user_second_factor_backup, user: user) }

        describe "when second factor token is missing" do
          it "should return the right response" do
            post "/session.json", params: { login: user.username, password: "myawesomepassword" }

            expect(response.status).to eq(200)
            expect(response.parsed_body["error"]).to eq(
              I18n.t("login.invalid_second_factor_method"),
            )
          end
        end

        describe "when second factor token is invalid" do
          context "when using totp method" do
            it "should return the right response" do
              post "/session.json",
                   params: {
                     login: user.username,
                     password: "myawesomepassword",
                     second_factor_token: "00000000",
                     second_factor_method: UserSecondFactor.methods[:totp],
                   }

              expect(response.status).to eq(200)
              expect(response.parsed_body["error"]).to eq(
                I18n.t("login.invalid_second_factor_code"),
              )
            end
          end

          context "when using backup code method" do
            it "should return the right response" do
              post "/session.json",
                   params: {
                     login: user.username,
                     password: "myawesomepassword",
                     second_factor_token: "00000000",
                     second_factor_method: UserSecondFactor.methods[:backup_codes],
                   }

              expect(response.status).to eq(200)
              expect(response.parsed_body["error"]).to eq(
                I18n.t("login.invalid_second_factor_code"),
              )
            end
          end
        end

        describe "when second factor token is valid" do
          context "when using totp method" do
            it "should log the user in" do
              post "/session.json",
                   params: {
                     login: user.username,
                     password: "myawesomepassword",
                     second_factor_token: ROTP::TOTP.new(user_second_factor.data).now,
                     second_factor_method: UserSecondFactor.methods[:totp],
                   }
              expect(response.status).to eq(200)
              expect(response.parsed_body["error"]).not_to be_present
              user.reload

              expect(session[:current_user_id]).to eq(user.id)
              expect(user.user_auth_tokens.count).to eq(1)

              unhashed_token = decrypt_auth_cookie(cookies[:_t])[:token]
              expect(UserAuthToken.hash_token(unhashed_token)).to eq(
                user.user_auth_tokens.first.auth_token,
              )
            end
          end

          context "when using backup code method" do
            it "should log the user in" do
              post "/session.json",
                   params: {
                     login: user.username,
                     password: "myawesomepassword",
                     second_factor_token: "iAmValidBackupCode",
                     second_factor_method: UserSecondFactor.methods[:backup_codes],
                   }
              expect(response.status).to eq(200)
              expect(response.parsed_body["error"]).not_to be_present
              user.reload

              expect(session[:current_user_id]).to eq(user.id)
              expect(user.user_auth_tokens.count).to eq(1)

              unhashed_token = decrypt_auth_cookie(cookies[:_t])[:token]
              expect(UserAuthToken.hash_token(unhashed_token)).to eq(
                user.user_auth_tokens.first.auth_token,
              )
            end
          end
        end
      end

      describe "with a blocked IP" do
        it "doesn't log in" do
          ScreenedIpAddress.all.destroy_all
          get "/"
          _screened_ip = Fabricate(:screened_ip_address, ip_address: request.remote_ip)
          post "/session.json",
               params: {
                 login: "@" + user.username,
                 password: "myawesomepassword",
               }
          expect(response.status).to eq(200)
          expect(response.parsed_body["error"]).to be_present
          user.reload

          expect(session[:current_user_id]).to be_nil
        end
      end

      describe "strips leading @ symbol" do
        it "sets a session id" do
          post "/session.json",
               params: {
                 login: "@" + user.username,
                 password: "myawesomepassword",
               }
          expect(response.status).to eq(200)
          expect(response.parsed_body["error"]).not_to be_present
          user.reload

          expect(session[:current_user_id]).to eq(user.id)
        end
      end

      describe "also allow login by email" do
        it "sets a session id" do
          post "/session.json", params: { login: user.email, password: "myawesomepassword" }
          expect(response.status).to eq(200)
          expect(response.parsed_body["error"]).not_to be_present
          expect(session[:current_user_id]).to eq(user.id)
        end
      end

      context "when login has leading and trailing space" do
        let(:username) { " #{user.username} " }
        let(:email) { " #{user.email} " }

        it "strips spaces from the username" do
          post "/session.json", params: { login: username, password: "myawesomepassword" }
          expect(response.status).to eq(200)
          expect(response.parsed_body["error"]).not_to be_present
        end

        it "strips spaces from the email" do
          post "/session.json", params: { login: email, password: "myawesomepassword" }
          expect(response.status).to eq(200)
          expect(response.parsed_body["error"]).not_to be_present
        end
      end

      describe "when the site requires approval of users" do
        before { SiteSetting.must_approve_users = true }

        context "with an unapproved user" do
          before do
            user.update_columns(approved: false)
            post "/session.json", params: { login: user.email, password: "myawesomepassword" }
          end

          it "doesn't log in the user" do
            expect(response.status).to eq(200)
            expect(response.parsed_body["error"]).to be_present
            expect(session[:current_user_id]).to be_blank
          end

          it "shows the 'not approved' error message" do
            expect(response.status).to eq(200)
            expect(response.parsed_body["error"]).to eq(I18n.t("login.not_approved"))
          end
        end

        context "with an unapproved user who is an admin" do
          it "sets a session id" do
            user.admin = true
            user.save!

            post "/session.json", params: { login: user.email, password: "myawesomepassword" }
            expect(response.status).to eq(200)
            expect(response.parsed_body["error"]).not_to be_present
            expect(session[:current_user_id]).to eq(user.id)
          end
        end
      end

      context "when admins are restricted by ip address" do
        before do
          SiteSetting.use_admin_ip_allowlist = true
          ScreenedIpAddress.all.destroy_all
        end

        it "is successful for admin at the ip address" do
          get "/"
          Fabricate(
            :screened_ip_address,
            ip_address: request.remote_ip,
            action_type: ScreenedIpAddress.actions[:allow_admin],
          )

          user.admin = true
          user.save!

          post "/session.json", params: { login: user.username, password: "myawesomepassword" }
          expect(response.status).to eq(200)
          expect(response.parsed_body["error"]).not_to be_present
          expect(session[:current_user_id]).to eq(user.id)
        end

        it "returns an error for admin not at the ip address" do
          Fabricate(
            :screened_ip_address,
            ip_address: "111.234.23.11",
            action_type: ScreenedIpAddress.actions[:allow_admin],
          )
          user.admin = true
          user.save!

          post "/session.json", params: { login: user.username, password: "myawesomepassword" }

          expect(response.status).to eq(200)
          expect(response.parsed_body["error"]).to be_present
          expect(session[:current_user_id]).not_to eq(user.id)
        end

        it "is successful for non-admin not at the ip address" do
          Fabricate(
            :screened_ip_address,
            ip_address: "111.234.23.11",
            action_type: ScreenedIpAddress.actions[:allow_admin],
          )
          user.admin = false
          user.save!

          post "/session.json", params: { login: user.username, password: "myawesomepassword" }

          expect(response.status).to eq(200)
          expect(response.parsed_body["error"]).not_to be_present
          expect(session[:current_user_id]).to eq(user.id)
        end
      end
    end

    context "when email has not been confirmed" do
      def post_login
        post "/session.json", params: { login: user.email, password: "myawesomepassword" }
      end

      it "doesn't log in the user" do
        post_login
        expect(response.status).to eq(200)
        expect(response.parsed_body["error"]).to be_present
        expect(session[:current_user_id]).to be_blank
      end

      it "shows the 'not activated' error message" do
        post_login
        expect(response.status).to eq(200)
        expect(response.parsed_body["error"]).to eq(I18n.t "login.not_activated")
      end

      context "when the 'must approve users' site setting is enabled" do
        before { SiteSetting.must_approve_users = true }

        it "shows the 'not approved' error message" do
          post_login
          expect(response.status).to eq(200)
          expect(response.parsed_body["error"]).to eq(I18n.t "login.not_approved")
        end
      end
    end

    context "when rate limited" do
      before { RateLimiter.enable }

      it "rate limits login" do
        SiteSetting.max_logins_per_ip_per_hour = 2
        EmailToken.confirm(email_token.token)

        2.times do
          post "/session.json", params: { login: user.username, password: "myawesomepassword" }

          expect(response.status).to eq(200)
          expect(response.parsed_body["error"]).not_to be_present
        end

        post "/session.json", params: { login: user.username, password: "myawesomepassword" }

        expect(response.status).to eq(429)
        json = response.parsed_body
        expect(json["error_type"]).to eq("rate_limit")
      end

      it "rate limits second factor attempts by IP" do
        6.times do |x|
          post "/session.json",
               params: {
                 login: "#{user.username}#{x}",
                 password: "myawesomepassword",
                 second_factor_token: "000000",
                 second_factor_method: UserSecondFactor.methods[:totp],
               }
          expect(response.status).to eq(200)
          expect(response.parsed_body["error"]).to be_present
        end

        post "/session.json",
             params: {
               login: user.username,
               password: "myawesomepassword",
               second_factor_token: "000000",
               second_factor_method: UserSecondFactor.methods[:totp],
             }

        expect(response.status).to eq(429)
        json = response.parsed_body
        expect(json["error_type"]).to eq("rate_limit")
      end

      it "rate limits second factor attempts by login" do
        EmailToken.confirm(email_token.token)

        6.times do |x|
          post "/session.json",
               params: {
                 login: user.username,
                 password: "myawesomepassword",
                 second_factor_token: "000000",
                 second_factor_method: UserSecondFactor.methods[:totp],
               },
               env: {
                 REMOTE_ADDR: "1.2.3.#{x}",
               }

          expect(response.status).to eq(200)
          expect(response.parsed_body["error"]).not_to be_present
        end

        [
          user.username + " ",
          user.username.capitalize,
          user.username,
        ].each_with_index do |username, x|
          post "/session.json",
               params: {
                 login: username,
                 password: "myawesomepassword",
                 second_factor_token: "000000",
                 second_factor_method: UserSecondFactor.methods[:totp],
               },
               env: {
                 REMOTE_ADDR: "1.2.4.#{x}",
               }

          expect(response.status).to eq(429)
          json = response.parsed_body
          expect(json["error_type"]).to eq("rate_limit")
        end
      end
    end
  end

  describe "#destroy" do
    it "removes the session variable and the auth token cookies" do
      user = sign_in(Fabricate(:user))
      delete "/session/#{user.username}.json"

      expect(response.status).to eq(302)
      expect(session[:current_user_id]).to be_blank
      expect(response.cookies["_t"]).to be_blank
    end

    it "returns the redirect URL in the body for XHR requests" do
      user = sign_in(Fabricate(:user))
      delete "/session/#{user.username}.json", xhr: true

      expect(response.status).to eq(200)
      expect(response.parsed_body["error"]).not_to be_present
      expect(session[:current_user_id]).to be_blank
      expect(response.cookies["_t"]).to be_blank

      expect(response.parsed_body["redirect_url"]).to eq("/")
    end

    it "redirects to /login when SSO and login_required" do
      SiteSetting.discourse_connect_url = "https://example.com/sso"
      SiteSetting.enable_discourse_connect = true

      user = sign_in(Fabricate(:user))
      delete "/session/#{user.username}.json", xhr: true
      expect(response.status).to eq(200)
      expect(response.parsed_body["error"]).not_to be_present
      expect(response.parsed_body["redirect_url"]).to eq("/")

      SiteSetting.login_required = true
      user = sign_in(Fabricate(:user))
      delete "/session/#{user.username}.json", xhr: true
      expect(response.status).to eq(200)
      expect(response.parsed_body["error"]).not_to be_present
      expect(response.parsed_body["redirect_url"]).to eq("/login")
    end

    it "allows plugins to manipulate redirect URL" do
      callback = ->(data) { data[:redirect_url] = "/myredirect/#{data[:user].username}" }

      DiscourseEvent.on(:before_session_destroy, &callback)

      user = sign_in(Fabricate(:user))
      delete "/session/#{user.username}.json", xhr: true

      expect(response.status).to eq(200)
      expect(response.parsed_body["error"]).not_to be_present
      expect(response.parsed_body["redirect_url"]).to eq("/myredirect/#{user.username}")
    ensure
      DiscourseEvent.off(:before_session_destroy, &callback)
    end

    it "includes ip and user agent in the before_session_destroy event params" do
      callback_params = {}
      callback = ->(data) { callback_params = data }

      DiscourseEvent.on(:before_session_destroy, &callback)

      user = sign_in(Fabricate(:user))
      delete "/session/#{user.username}.json",
             xhr: true,
             headers: {
               HTTP_USER_AGENT: "AwesomeBrowser",
             }

      expect(callback_params[:user_agent]).to eq("AwesomeBrowser")
      expect(callback_params[:client_ip]).to eq("127.0.0.1")
    ensure
      DiscourseEvent.off(:before_session_destroy, &callback)
    end
  end

  describe "#one_time_password" do
    context "with missing token" do
      it "returns the right response" do
        get "/session/otp"
        expect(response.status).to eq(404)
      end
    end

    context "with invalid token" do
      it "returns the right response" do
        get "/session/otp/asd1231dasd123"

        expect(response.status).to eq(404)

        post "/session/otp/asd1231dasd123"

        expect(response.status).to eq(404)
      end

      context "when token is valid" do
        it "should display the form for GET" do
          token = SecureRandom.hex
          Discourse.redis.setex "otp_#{token}", 10.minutes, user.username

          get "/session/otp/#{token}"

          expect(response.status).to eq(200)
          expect(response.parsed_body["error"]).not_to be_present
          expect(response.body).to include(
            I18n.t("user_api_key.otp_confirmation.logging_in_as", username: user.username),
          )
          expect(Discourse.redis.get("otp_#{token}")).to eq(user.username)

          expect(session[:current_user_id]).to eq(nil)
        end

        it "should redirect on GET if already logged in" do
          sign_in(user)
          token = SecureRandom.hex
          Discourse.redis.setex "otp_#{token}", 10.minutes, user.username

          get "/session/otp/#{token}"
          expect(response.status).to eq(302)

          expect(Discourse.redis.get("otp_#{token}")).to eq(nil)
          expect(session[:current_user_id]).to eq(user.id)
        end

        it "should authenticate user and delete token" do
          user = Fabricate(:user)

          get "/session/current.json"
          expect(response.status).to eq(404)

          token = SecureRandom.hex
          Discourse.redis.setex "otp_#{token}", 10.minutes, user.username

          post "/session/otp/#{token}"

          expect(response.status).to eq(302)
          expect(response).to redirect_to("/")
          expect(Discourse.redis.get("otp_#{token}")).to eq(nil)

          get "/session/current.json"
          expect(response.status).to eq(200)
          expect(response.parsed_body["error"]).not_to be_present
        end
      end
    end
  end

  describe "#forgot_password" do
    context "when hide_email_address_taken is set" do
      before { SiteSetting.hide_email_address_taken = true }

      it "denies for username" do
        post "/session/forgot_password.json", params: { login: user.username }

        expect(response.status).to eq(400)
        expect(Jobs::CriticalUserEmail.jobs.size).to eq(0)
      end

      it "allows for username when staff" do
        sign_in(Fabricate(:admin))

        post "/session/forgot_password.json", params: { login: user.username }

        expect(response.status).to eq(200)
        expect(response.parsed_body["error"]).not_to be_present
        expect(Jobs::CriticalUserEmail.jobs.size).to eq(1)
      end

      it "allows for email" do
        post "/session/forgot_password.json", params: { login: user.email }

        expect(response.status).to eq(200)
        expect(response.parsed_body["error"]).not_to be_present
        expect(Jobs::CriticalUserEmail.jobs.size).to eq(1)
      end
    end

    it "raises an error without a username parameter" do
      post "/session/forgot_password.json"
      expect(response.status).to eq(400)
    end

    it "should correctly screen ips" do
      ScreenedIpAddress.create!(
        ip_address: "100.0.0.1",
        action_type: ScreenedIpAddress.actions[:block],
      )

      post "/session/forgot_password.json",
           params: {
             login: "made_up",
           },
           headers: {
             "REMOTE_ADDR" => "100.0.0.1",
           }

      expect(response.parsed_body).to eq(
        { "errors" => [I18n.t("login.reset_not_allowed_from_ip_address")] },
      )
    end

    describe "rate limiting" do
      before { RateLimiter.enable }

      it "should correctly rate limits" do
        user = Fabricate(:user)

        3.times do
          post "/session/forgot_password.json", params: { login: user.username }
          expect(response.status).to eq(200)
          expect(response.parsed_body["error"]).not_to be_present
        end

        post "/session/forgot_password.json", params: { login: user.username }
        expect(response.status).to eq(422)

        3.times do
          post "/session/forgot_password.json",
               params: {
                 login: user.username,
               },
               headers: {
                 "REMOTE_ADDR" => "10.1.1.1",
               }

          expect(response.status).to eq(200)
          expect(response.parsed_body["error"]).not_to be_present
        end

        post "/session/forgot_password.json",
             params: {
               login: user.username,
             },
             headers: {
               "REMOTE_ADDR" => "100.1.1.1",
             }

        # not allowed, max 6 a day
        expect(response.status).to eq(422)
      end
    end

    context "for a non existant username" do
      it "doesn't generate a new token for a made up username" do
        expect do
          post "/session/forgot_password.json", params: { login: "made_up" }
        end.not_to change(EmailToken, :count)
        expect(Jobs::CriticalUserEmail.jobs.size).to eq(0)
      end
    end

    context "for an existing username" do
      fab!(:user)

      context "when local login is disabled" do
        before do
          SiteSetting.enable_local_logins = false
          post "/session/forgot_password.json", params: { login: user.username }
        end
        it_behaves_like "failed to continue local login"
      end

      context "when SSO is enabled" do
        before do
          SiteSetting.discourse_connect_url = "https://www.example.com/sso"
          SiteSetting.enable_discourse_connect = true

          post "/session.json", params: { login: user.username, password: "myawesomepassword" }
        end
        it_behaves_like "failed to continue local login"
      end

      context "when local logins are disabled" do
        before do
          SiteSetting.enable_local_logins = false

          post "/session.json", params: { login: user.username, password: "myawesomepassword" }
        end
        it_behaves_like "failed to continue local login"
      end

      context "when local logins via email are disabled" do
        before { SiteSetting.enable_local_logins_via_email = false }
        it "does not matter, generates a new token for a made up username" do
          expect do
            post "/session/forgot_password.json", params: { login: user.username }
          end.to change(EmailToken, :count)
        end
      end

      it "generates a new token for a made up username" do
        expect do
          post "/session/forgot_password.json", params: { login: user.username }
        end.to change(EmailToken, :count)
      end

      it "enqueues an email" do
        post "/session/forgot_password.json", params: { login: user.username }
        expect(Jobs::CriticalUserEmail.jobs.size).to eq(1)
      end
    end

    context "when doing nothing to system username" do
      let(:system) { Discourse.system_user }

      it "generates no token for system username" do
        expect do
          post "/session/forgot_password.json", params: { login: system.username }
        end.not_to change(EmailToken, :count)
      end

      it "enqueues no email" do
        post "/session/forgot_password.json", params: { login: system.username }
        expect(Jobs::CriticalUserEmail.jobs.size).to eq(0)
      end
    end

    context "for a staged account" do
      let!(:staged) { Fabricate(:staged) }

      it "generates no token for staged username" do
        expect do
          post "/session/forgot_password.json", params: { login: staged.username }
        end.not_to change(EmailToken, :count)
      end

      it "enqueues no email" do
        post "/session/forgot_password.json", params: { login: staged.username }
        expect(Jobs::CriticalUserEmail.jobs.size).to eq(0)
      end
    end

    context "when in staff writes only mode" do
      before { Discourse.enable_readonly_mode(Discourse::STAFF_WRITES_ONLY_MODE_KEY) }

      it "allows staff to forget their password" do
        post "/session/forgot_password.json", params: { login: admin.username }
        expect(response.status).to eq(200)
        expect(response.parsed_body["error"]).not_to be_present
        expect(Jobs::CriticalUserEmail.jobs.size).to eq(1)
      end

      it "doesn't allow non-staff to forget their password" do
        post "/session/forgot_password.json", params: { login: user.username }
        expect(response.status).to eq(503)
        expect(Jobs::CriticalUserEmail.jobs.size).to eq(0)
      end
    end
  end

  describe "#current" do
    context "when not logged in" do
      it "returns 404" do
        get "/session/current.json"
        expect(response.status).to eq(404)
      end
    end

    context "when logged in" do
      let!(:user) { sign_in(Fabricate(:user)) }

      it "returns the JSON for the user" do
        get "/session/current.json"
        expect(response.status).to eq(200)
        expect(response.parsed_body["error"]).not_to be_present
        json = response.parsed_body
        expect(json["current_user"]).to be_present
        expect(json["current_user"]["id"]).to eq(user.id)
      end
    end
  end

  describe "#second_factor_auth_show" do
    let!(:user_second_factor) { Fabricate(:user_second_factor_totp, user: user) }

    it "can work for anon" do
      post "/session/2fa/test-action?username=#{user.username}", xhr: true
      expect(response.status).to eq(403)

      nonce = response.parsed_body["second_factor_challenge_nonce"]
      get "/session/2fa.json", params: { nonce: nonce }
      expect(response.status).to eq(200)
      expect(response.parsed_body["error"]).not_to be_present
    end

    it "throws an error if logged in to a different user" do
      sign_in user
      other_user = Fabricate(:user)
      post "/session/2fa/test-action?username=#{other_user.username}", xhr: true

      expect(response.status).to eq(400)
      expect(response.parsed_body["result"]).to eq("wrong user")
    end

    context "when logged in" do
      before { sign_in(user) }

      it "returns 404 if there is no challenge for the given nonce" do
        get "/session/2fa.json", params: { nonce: "asdasdsadsad" }
        expect(response.status).to eq(404)
        expect(response.parsed_body["error"]).to eq(
          I18n.t("second_factor_auth.challenge_not_found"),
        )
      end

      it "returns 404 if the nonce does not match the challenge nonce" do
        post "/session/2fa/test-action"
        get "/session/2fa.json", params: { nonce: "wrongnonce" }
        expect(response.status).to eq(404)
        expect(response.parsed_body["error"]).to eq(
          I18n.t("second_factor_auth.challenge_not_found"),
        )
      end

      it "returns 401 if the challenge nonce has expired" do
        post "/session/2fa/test-action", xhr: true
        nonce = response.parsed_body["second_factor_challenge_nonce"]
        get "/session/2fa.json", params: { nonce: nonce }
        expect(response.status).to eq(200)
        expect(response.parsed_body["error"]).not_to be_present

        freeze_time (SecondFactor::AuthManager::MAX_CHALLENGE_AGE + 1.minute).from_now
        get "/session/2fa.json", params: { nonce: nonce }
        expect(response.status).to eq(401)
        expect(response.parsed_body["error"]).to eq(I18n.t("second_factor_auth.challenge_expired"))
      end

      it "responds with challenge data" do
        post "/session/2fa/test-action", xhr: true
        nonce = response.parsed_body["second_factor_challenge_nonce"]
        get "/session/2fa.json", params: { nonce: nonce }
        expect(response.status).to eq(200)
        expect(response.parsed_body["error"]).not_to be_present
        challenge_data = response.parsed_body
        expect(challenge_data["totp_enabled"]).to eq(true)
        expect(challenge_data["backup_enabled"]).to eq(false)
        expect(challenge_data["security_keys_enabled"]).to eq(false)
        expect(challenge_data["allowed_methods"]).to contain_exactly(
          UserSecondFactor.methods[:totp],
          UserSecondFactor.methods[:security_key],
        )
        expect(challenge_data["description"]).to eq("this is description for test action")

        Fabricate(
          :user_security_key_with_random_credential,
          user: user,
          name: "Enabled YubiKey",
          enabled: true,
        )
        Fabricate(:user_second_factor_backup, user: user)
        post "/session/2fa/test-action", params: { allow_backup_codes: true }, xhr: true
        nonce = response.parsed_body["second_factor_challenge_nonce"]
        get "/session/2fa.json", params: { nonce: nonce }
        expect(response.status).to eq(200)
        expect(response.parsed_body["error"]).not_to be_present
        challenge_data = response.parsed_body
        expect(challenge_data["totp_enabled"]).to eq(true)
        expect(challenge_data["backup_enabled"]).to eq(true)
        expect(challenge_data["security_keys_enabled"]).to eq(true)
        expect(challenge_data["allowed_credential_ids"]).to be_present
        expect(challenge_data["challenge"]).to be_present
        expect(challenge_data["allowed_methods"]).to contain_exactly(
          UserSecondFactor.methods[:totp],
          UserSecondFactor.methods[:security_key],
          UserSecondFactor.methods[:backup_codes],
        )
      end
    end
  end

  describe "#second_factor_auth_perform" do
    let!(:user_second_factor) { Fabricate(:user_second_factor_totp, user: user) }

    it "works as anon" do
      post "/session/2fa/test-action?username=#{user.username}", xhr: true
      nonce = response.parsed_body["second_factor_challenge_nonce"]

      token = ROTP::TOTP.new(user_second_factor.data).now
      post "/session/2fa.json",
           params: {
             nonce: nonce,
             second_factor_method: UserSecondFactor.methods[:totp],
             second_factor_token: token,
           }
      expect(response.status).to eq(200)
      expect(response.parsed_body["error"]).not_to be_present

      post "/session/2fa/test-action?username=#{user.username}",
           params: {
             second_factor_nonce: nonce,
           }
      expect(response.status).to eq(200)
      expect(response.parsed_body["error"]).not_to be_present
      expect(response.parsed_body["result"]).to eq("second_factor_auth_completed")
    end

    it "prevents use by different user" do
      other_user = Fabricate(:user)

      post "/session/2fa/test-action?username=#{user.username}", xhr: true
      expect(response.status).to eq(403)
    end

    context "when signed in" do
      before { sign_in(user) }

      it "returns 401 if the challenge nonce has expired" do
        post "/session/2fa/test-action", xhr: true
        nonce = response.parsed_body["second_factor_challenge_nonce"]

        freeze_time (SecondFactor::AuthManager::MAX_CHALLENGE_AGE + 1.minute).from_now
        token = ROTP::TOTP.new(user_second_factor.data).now
        post "/session/2fa.json",
             params: {
               nonce: nonce,
               second_factor_method: UserSecondFactor.methods[:totp],
               second_factor_token: token,
             }
        expect(response.status).to eq(401)
        expect(response.parsed_body["error"]).to eq(I18n.t("second_factor_auth.challenge_expired"))
      end

      it "returns 403 if the 2FA method is not allowed" do
        Fabricate(:user_second_factor_backup, user: user)
        post "/session/2fa/test-action", xhr: true
        nonce = response.parsed_body["second_factor_challenge_nonce"]
        post "/session/2fa.json",
             params: {
               nonce: nonce,
               second_factor_method: UserSecondFactor.methods[:backup_codes],
               second_factor_token: "iAmValidBackupCode",
             }
        expect(response.status).to eq(403)
      end

      it "returns 403 if the user disables the 2FA method in the middle of the 2FA process" do
        post "/session/2fa/test-action", xhr: true
        nonce = response.parsed_body["second_factor_challenge_nonce"]
        token = ROTP::TOTP.new(user_second_factor.data).now
        user_second_factor.destroy!
        post "/session/2fa.json",
             params: {
               nonce: nonce,
               second_factor_method: UserSecondFactor.methods[:totp],
               second_factor_token: token,
             }
        expect(response.status).to eq(403)
      end

      it "marks the challenge as successful if the 2fa succeeds" do
        post "/session/2fa/test-action", params: { redirect_url: "/ggg" }, xhr: true
        nonce = response.parsed_body["second_factor_challenge_nonce"]

        token = ROTP::TOTP.new(user_second_factor.data).now
        post "/session/2fa.json",
             params: {
               nonce: nonce,
               second_factor_method: UserSecondFactor.methods[:totp],
               second_factor_token: token,
             }
        expect(response.status).to eq(200)
        expect(response.parsed_body["error"]).not_to be_present
        expect(response.parsed_body["ok"]).to eq(true)
        expect(response.parsed_body["callback_method"]).to eq("POST")
        expect(response.parsed_body["callback_path"]).to eq("/session/2fa/test-action")
        expect(response.parsed_body["redirect_url"]).to eq("/ggg")

        post "/session/2fa/test-action", params: { second_factor_nonce: nonce }
        expect(response.status).to eq(200)
        expect(response.parsed_body["error"]).not_to be_present
        expect(response.parsed_body["result"]).to eq("second_factor_auth_completed")
      end

      it "does not mark the challenge as successful if the 2fa fails" do
        post "/session/2fa/test-action", params: { redirect_url: "/ggg" }, xhr: true
        nonce = response.parsed_body["second_factor_challenge_nonce"]

        token = ROTP::TOTP.new(user_second_factor.data).now.to_i
        token += token == 999_999 ? -1 : 1
        post "/session/2fa.json",
             params: {
               nonce: nonce,
               second_factor_method: UserSecondFactor.methods[:totp],
               second_factor_token: token.to_s,
             }
        expect(response.status).to eq(400)
        expect(response.parsed_body["ok"]).to eq(false)
        expect(response.parsed_body["reason"]).to eq("invalid_second_factor")
        expect(response.parsed_body["error"]).to eq(I18n.t("login.invalid_second_factor_code"))

        post "/session/2fa/test-action", params: { second_factor_nonce: nonce }
        expect(response.status).to eq(401)
      end
    end
  end

  describe "#passkey_challenge" do
    it "returns a challenge for an anonymous user" do
      get "/session/passkey/challenge.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["challenge"]).not_to eq(nil)
    end

    it "returns a challenge for an authenticated user" do
      sign_in(user)
      get "/session/passkey/challenge.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["challenge"]).not_to eq(nil)
    end

    it "reset challenge on subsequent calls" do
      get "/session/passkey/challenge.json"
      expect(response.status).to eq(200)
      challenge1 = response.parsed_body["challenge"]

      get "/session/passkey/challenge.json"
      expect(response.parsed_body["challenge"]).not_to eq(challenge1)
    end

    it "fails if local logins are not allowed" do
      SiteSetting.enable_local_logins = false

      get "/session/passkey/challenge.json"
      expect(response.status).to eq(403)
    end
  end

  describe "#passkey_login" do
    before { DiscourseWebauthn.stubs(:origin).returns("http://localhost:3000") }

    it "returns 404 if feature is not enabled" do
      SiteSetting.enable_passkeys = false

      post "/session/passkey/auth.json"
      expect(response.status).to eq(404)
    end

    context "when enable_passkeys is enabled" do
      before { SiteSetting.enable_passkeys = true }

      it "fails if public key param is missing" do
        post "/session/passkey/auth.json"
        expect(response.status).to eq(400)

        json = response.parsed_body
        expect(json["errors"][0]).to include("param is missing")
        expect(json["errors"][0]).to include("publicKeyCredential")
      end

      it "fails on malformed credentials" do
        post "/session/passkey/auth.json", params: { publicKeyCredential: "someboringstring" }
        expect(response.status).to eq(401)

        json = response.parsed_body
        expect(json["errors"][0]).to eq(
          I18n.t("webauthn.validation.malformed_public_key_credential_error"),
        )
      end

      it "fails on invalid credentials" do
        post "/session/passkey/auth.json",
             params: {
               # creds are well-formed but security key is not registered
               publicKeyCredential: {
                 signature:
                   "MEYCIQDYtbfkTGHOfizXHBHltn5KOq1eC3EM6Uq4peZ0L+3wMwIhAMgzm88qOOZ7SPYh5M6zvKMjVsUAne7n9RKdN/4Bb6z8",
                 clientData:
                   "eyJ0eXBlIjoid2ViYXV0aG4uZ2V0IiwiY2hhbGxlbmdlIjoiWmpJMk16UmxNMlV3TkRSaFl6QmhNemczTURjMlpUaGhaR1l5T1dGaU5qSXpNamMxWmpCaU9EVmxNVFUzTURaaVpEaGpNVEUwTVdJeU1qRXkiLCJvcmlnaW4iOiJodHRwOi8vbG9jYWxob3N0OjMwMDAiLCJjcm9zc09yaWdpbiI6ZmFsc2x9",
                 authenticatorData: "SZYN5YgOjGh0NBcPZHZgW4/krrmihjLHmVzzuoMdl2MFAAAAAA==",
                 credentialId: "humAArAAAiZZuwFE/F9Gi4BAVTsRL/FowuzQsYTPKIk=",
               },
             }

        expect(response.status).to eq(401)
        json = response.parsed_body
        expect(json["errors"][0]).to eq(I18n.t("webauthn.validation.not_found_error"))
      end

      context "when user has a valid registered passkey" do
        let!(:passkey) do
          Fabricate(
            :user_security_key,
            credential_id: valid_passkey_data[:credential_id],
            public_key: valid_passkey_data[:public_key],
            user: user,
            factor_type: UserSecurityKey.factor_types[:first_factor],
            last_used: nil,
            name: "A key",
          )
        end

        it "fails if local logins are not allowed" do
          SiteSetting.enable_local_logins = false

          post "/session/passkey/auth.json",
               params: {
                 publicKeyCredential: valid_passkey_auth_data,
               }
          expect(response.status).to eq(403)
        end

        it "fails when the key is registered to another user" do
          simulate_localhost_passkey_challenge
          user.activate
          user.create_or_fetch_secure_identifier
          post "/session/passkey/auth.json",
               params: {
                 publicKeyCredential:
                   valid_passkey_auth_data.merge(
                     { userHandle: Base64.strict_encode64(SecureRandom.hex(20)) },
                   ),
               }
          expect(response.status).to eq(401)
          json = response.parsed_body
          expect(json["errors"][0]).to eq(I18n.t("webauthn.validation.ownership_error"))
          expect(session[:current_user_id]).to eq(nil)
        end

        it "logs the user in" do
          simulate_localhost_passkey_challenge
          user.activate
          user.create_or_fetch_secure_identifier
          post "/session/passkey/auth.json",
               params: {
                 publicKeyCredential:
                   valid_passkey_auth_data.merge(
                     { userHandle: Base64.strict_encode64(user.secure_identifier) },
                   ),
               }
          expect(response.status).to eq(200)
          expect(response.parsed_body["error"]).not_to be_present

          expect(session[:current_user_id]).to eq(user.id)
        end

        context "with a valid discourse connect provider" do
          before do
            sso = DiscourseConnectBase.new
            sso.nonce = "mynonce"
            sso.sso_secret = "topsecret"
            sso.return_sso_url = "http://somewhere.over.rainbow/sso"
            cookies[:sso_payload] = sso.payload

            provider_uid = 12_345
            UserAssociatedAccount.create!(
              provider_name: "google_oauth2",
              provider_uid: provider_uid,
              user: user,
            )

            SiteSetting.enable_discourse_connect_provider = true
            SiteSetting.discourse_connect_secret = sso.sso_secret
            SiteSetting.discourse_connect_provider_secrets =
              "somewhere.over.rainbow|#{sso.sso_secret}"
          end

          it "logs the user in" do
            simulate_localhost_passkey_challenge
            user.activate
            user.create_or_fetch_secure_identifier
            post "/session/passkey/auth.json",
                 params: {
                   publicKeyCredential:
                     valid_passkey_auth_data.merge(
                       { userHandle: Base64.strict_encode64(user.secure_identifier) },
                     ),
                 }
            expect(response.status).to eq(302)
            expect(response.location).to start_with("http://somewhere.over.rainbow/sso")
          end
        end
      end
    end
  end

  describe "#scopes" do
    context "when not a valid api request" do
      it "returns 404" do
        get "/session/scopes.json"
        expect(response.status).to eq(404)
      end
    end

    context "when a valid api request" do
      let(:admin) { Fabricate(:admin) }
      let(:scope) do
        ApiKeyScope.new(resource: "topics", action: "read", allowed_parameters: { topic_id: "3" })
      end
      let(:api_key) { Fabricate(:api_key, user: admin, api_key_scopes: [scope]) }

      it "returns the scopes of the api key" do
        get "/session/scopes.json",
            headers: {
              "Api-Key": api_key.key,
              "Api-Username": admin.username,
            }
        expect(response.status).to eq(200)

        json = response.parsed_body
        expect(json["scopes"].size).to eq(1)
        expect(json["scopes"].first["resource"]).to eq("topics")
        expect(json["scopes"].first["action"]).to eq("read")
        expect(json["scopes"].first["allowed_parameters"]).to eq({ topic_id: "3" }.as_json)
      end
    end
  end
end
