# frozen_string_literal: true

require 'rails_helper'
require 'rotp'

describe SessionController do
  let(:user) { Fabricate(:user) }
  let(:email_token) { Fabricate(:email_token, user: user) }

  shared_examples 'failed to continue local login' do
    it 'should return the right response' do
      expect(response).not_to be_successful
      expect(response.status).to eq(403)
    end
  end

  describe '#email_login_info' do
    let(:email_token) { Fabricate(:email_token, user: user, scope: EmailToken.scopes[:email_login]) }

    before do
      SiteSetting.enable_local_logins_via_email = true
    end

    context "when local logins via email disabled" do
      before { SiteSetting.enable_local_logins_via_email = false }

      it "only works for admins" do
        get "/session/email-login/#{email_token.token}.json"
        expect(response.status).to eq(403)

        user.update(admin: true)
        get "/session/email-login/#{email_token.token}.json"
        expect(response.status).to eq(200)
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
      end
    end

    context 'missing token' do
      it 'returns the right response' do
        get "/session/email-login"
        expect(response.status).to eq(404)
      end
    end

    context 'valid token' do
      it 'returns information' do
        get "/session/email-login/#{email_token.token}.json"

        expect(response.parsed_body["can_login"]).to eq(true)
        expect(response.parsed_body["second_factor_required"]).to eq(nil)

        # Does not log in the user
        expect(session[:current_user_id]).to be_nil
      end

      it 'fails when local logins via email is disabled' do
        SiteSetting.enable_local_logins_via_email = false

        get "/session/email-login/#{email_token.token}.json"

        expect(response.status).to eq(403)
      end

      it 'fails when local logins is disabled' do
        SiteSetting.enable_local_logins = false

        get "/session/email-login/#{email_token.token}.json"

        expect(response.status).to eq(403)
      end

      context 'user has 2-factor logins' do
        let!(:user_second_factor) { Fabricate(:user_second_factor_totp, user: user) }
        let!(:user_second_factor_backup) { Fabricate(:user_second_factor_backup, user: user) }

        it "includes that information in the response" do
          get "/session/email-login/#{email_token.token}.json"

          response_body_parsed = response.parsed_body
          expect(response_body_parsed["can_login"]).to eq(true)
          expect(response_body_parsed["second_factor_required"]).to eq(true)
          expect(response_body_parsed["backup_codes_enabled"]).to eq(true)
        end
      end

      context 'user has security key enabled' do
        let!(:user_security_key) { Fabricate(:user_security_key, user: user) }

        it "includes that information in the response" do
          get "/session/email-login/#{email_token.token}.json"

          response_body_parsed = response.parsed_body
          expect(response_body_parsed["can_login"]).to eq(true)
          expect(response_body_parsed["security_key_required"]).to eq(true)
          expect(response_body_parsed["second_factor_required"]).to eq(nil)
          expect(response_body_parsed["backup_codes_enabled"]).to eq(nil)
          expect(response_body_parsed["allowed_credential_ids"]).to eq([user_security_key.credential_id])
          secure_session = SecureSession.new(session["secure_session_id"])
          expect(response_body_parsed["challenge"]).to eq(Webauthn.challenge(user, secure_session))
          expect(Webauthn.rp_id(user, secure_session)).to eq(Discourse.current_hostname)
        end
      end
    end
  end

  describe '#email_login' do
    let(:email_token) { Fabricate(:email_token, user: user, scope: EmailToken.scopes[:email_login]) }

    before do
      SiteSetting.enable_local_logins_via_email = true
    end

    context "when local logins via email disabled" do
      before { SiteSetting.enable_local_logins_via_email = false }

      it "only works for admins" do
        post "/session/email-login/#{email_token.token}.json"
        expect(response.status).to eq(403)

        user.update(admin: true)
        post "/session/email-login/#{email_token.token}.json"
        expect(response.status).to eq(200)
        expect(session[:current_user_id]).to eq(user.id)
      end
    end

    context 'missing token' do
      it 'returns the right response' do
        post "/session/email-login"
        expect(response.status).to eq(404)
      end
    end

    context 'invalid token' do
      it 'returns the right response' do
        post "/session/email-login/adasdad.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["error"]).to eq(
          I18n.t('email_login.invalid_token')
        )
      end

      context 'when token has expired' do
        it 'should return the right response' do
          email_token.update!(created_at: 999.years.ago)

          post "/session/email-login/#{email_token.token}.json"

          expect(response.status).to eq(200)

          expect(response.parsed_body["error"]).to eq(
            I18n.t('email_login.invalid_token')
          )
        end
      end
    end

    context 'valid token' do
      it 'returns success' do
        post "/session/email-login/#{email_token.token}.json"

        expect(response.parsed_body["success"]).to eq("OK")
        expect(session[:current_user_id]).to eq(user.id)
      end

      it 'fails when local logins via email is disabled' do
        SiteSetting.enable_local_logins_via_email = false

        post "/session/email-login/#{email_token.token}.json"

        expect(response.status).to eq(403)
        expect(session[:current_user_id]).to eq(nil)
      end

      it 'fails when local logins is disabled' do
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
          Fabricate(:screened_ip_address,
            ip_address: "111.111.11.11",
            action_type: ScreenedIpAddress.actions[:allow_admin]
          )

          SiteSetting.use_admin_ip_allowlist = true
          user.update!(admin: true)
        end

        it 'returns the right response' do
          post "/session/email-login/#{email_token.token}.json"

          expect(response.status).to eq(200)

          expect(response.parsed_body["error"]).to eq(
            I18n.t("login.admin_not_allowed_from_ip_address", username: user.username)
          )
          expect(session[:current_user_id]).to eq(nil)
        end
      end

      context "when IP address is blocked" do
        let(:permitted_ip_address) { '111.234.23.11' }

        before do
          Fabricate(:screened_ip_address,
            ip_address: permitted_ip_address,
            action_type: ScreenedIpAddress.actions[:block]
          )
        end

        it 'returns the right response' do
          ActionDispatch::Request.any_instance.stubs(:remote_ip).returns(permitted_ip_address)

          post "/session/email-login/#{email_token.token}.json"

          expect(response.status).to eq(200)

          expect(response.parsed_body["error"]).to eq(
            I18n.t("login.not_allowed_from_ip_address", username: user.username)
          )
          expect(session[:current_user_id]).to eq(nil)
        end
      end

      context "when timezone param is provided" do
        it "sets the user_option timezone for the user" do
          post "/session/email-login/#{email_token.token}.json", params: { timezone: "Australia/Melbourne" }
          expect(response.status).to eq(200)
          expect(user.reload.user_option.timezone).to eq("Australia/Melbourne")
        end
      end

      it "fails when user is suspended" do
        user.update!(
          suspended_till: 2.days.from_now,
          suspended_at: Time.zone.now
        )

        post "/session/email-login/#{email_token.token}.json"

        expect(response.status).to eq(200)

        expect(response.parsed_body["error"]).to eq(
          I18n.t("login.suspended", date: I18n.l(user.suspended_till, format: :date_only)
        ))
        expect(session[:current_user_id]).to eq(nil)
      end

      context 'user has 2-factor logins' do
        let!(:user_second_factor) { Fabricate(:user_second_factor_totp, user: user) }
        let!(:user_second_factor_backup) { Fabricate(:user_second_factor_backup, user: user) }

        describe 'errors on incorrect 2-factor' do
          context 'when using totp method' do
            it 'does not log in with incorrect two factor' do
              post "/session/email-login/#{email_token.token}.json", params: {
                second_factor_token: "0000",
                second_factor_method: UserSecondFactor.methods[:totp]
              }

              expect(response.status).to eq(200)

              expect(response.parsed_body["error"]).to eq(
                I18n.t("login.invalid_second_factor_code")
              )
              expect(session[:current_user_id]).to eq(nil)
            end
          end
          context 'when using backup code method' do
            it 'does not log in with incorrect backup code' do
              post "/session/email-login/#{email_token.token}.json", params: {
                second_factor_token: "0000",
                second_factor_method: UserSecondFactor.methods[:backup_codes]
              }

              expect(response.status).to eq(200)
              expect(response.parsed_body["error"]).to eq(
                I18n.t("login.invalid_second_factor_code")
              )
              expect(session[:current_user_id]).to eq(nil)
            end
          end
        end

        describe 'allows successful 2-factor' do
          context 'when using totp method' do
            it 'logs in correctly' do
              post "/session/email-login/#{email_token.token}.json", params: {
                second_factor_token: ROTP::TOTP.new(user_second_factor.data).now,
                second_factor_method: UserSecondFactor.methods[:totp]
              }

              expect(response.parsed_body["success"]).to eq("OK")
              expect(session[:current_user_id]).to eq(user.id)
            end
          end
          context 'when using backup code method' do
            it 'logs in correctly' do
              post "/session/email-login/#{email_token.token}.json", params: {
                second_factor_token: "iAmValidBackupCode",
                second_factor_method: UserSecondFactor.methods[:backup_codes]
              }

              expect(response.parsed_body["success"]).to eq("OK")
              expect(session[:current_user_id]).to eq(user.id)
            end
          end
        end

        context "if the security_key_param is provided but only TOTP is enabled" do
          it "does not log in the user" do
            post "/session/email-login/#{email_token.token}.json", params: {
              second_factor_token: 'foo',
              second_factor_method: UserSecondFactor.methods[:totp]
            }

            expect(response.status).to eq(200)

            expect(response.parsed_body["error"]).to eq(
              I18n.t("login.invalid_second_factor_code")
            )
            expect(session[:current_user_id]).to eq(nil)
          end
        end
      end

      context "user has only security key enabled" do
        let!(:user_security_key) do
          Fabricate(
            :user_security_key,
            user: user,
            credential_id: valid_security_key_data[:credential_id],
            public_key: valid_security_key_data[:public_key]
          )
        end

        before do
          simulate_localhost_webauthn_challenge

          # store challenge in secure session by visiting the email login page
          get "/session/email-login/#{email_token.token}.json"
        end

        context "when the security key params are blank and a random second factor token is provided" do
          it "shows an error message and denies login" do

            post "/session/email-login/#{email_token.token}.json", params: {
              second_factor_token: "XXXXXXX",
              second_factor_method: UserSecondFactor.methods[:totp]
            }

            expect(response.status).to eq(200)
            expect(session[:current_user_id]).to eq(nil)
            response_body = response.parsed_body
            expect(response_body['error']).to eq(I18n.t(
              'login.not_enabled_second_factor_method'
            ))
          end
        end
        context "when the security key params are invalid" do
          it "shows an error message and denies login" do

            post "/session/email-login/#{email_token.token}.json", params: {
              second_factor_token: {
                signature: 'bad_sig',
                clientData: 'bad_clientData',
                credentialId: 'bad_credential_id',
                authenticatorData: 'bad_authenticator_data'
              },
              second_factor_method: UserSecondFactor.methods[:security_key]
            }

            expect(response.status).to eq(200)
            expect(session[:current_user_id]).to eq(nil)
            response_body = response.parsed_body
            expect(response_body["failed"]).to eq("FAILED")
            expect(response_body['error']).to eq(I18n.t(
              'webauthn.validation.not_found_error'
            ))
          end
        end
        context "when the security key params are valid" do
          it "logs the user in" do

            post "/session/email-login/#{email_token.token}.json", params: {
              login: user.username,
              password: 'myawesomepassword',
              second_factor_token: valid_security_key_auth_post_data,
              second_factor_method: UserSecondFactor.methods[:security_key]
            }

            expect(response.status).to eq(200)
            user.reload

            expect(session[:current_user_id]).to eq(user.id)
            expect(user.user_auth_tokens.count).to eq(1)
          end
        end
      end

      context "user has security key and totp enabled" do
        let!(:user_security_key) do
          Fabricate(
            :user_security_key,
            user: user,
            credential_id: valid_security_key_data[:credential_id],
            public_key: valid_security_key_data[:public_key]
          )
        end
        let!(:user_second_factor) { Fabricate(:user_second_factor_totp, user: user) }

        it "doesnt allow logging in if the 2fa params are garbled" do
          post "/session/email-login/#{email_token.token}.json", params: {
            second_factor_method: UserSecondFactor.methods[:totp],
            second_factor_token: "blah"
          }

          expect(response.status).to eq(200)
          expect(session[:current_user_id]).to eq(nil)
          response_body = response.parsed_body
          expect(response_body['error']).to eq(I18n.t(
            'login.invalid_second_factor_code'
          ))
        end

        it "doesnt allow login if both of the 2fa params are blank" do
          post "/session/email-login/#{email_token.token}.json", params: {
            second_factor_method: UserSecondFactor.methods[:totp],
            second_factor_token: ""
          }

          expect(response.status).to eq(200)
          expect(session[:current_user_id]).to eq(nil)
          response_body = response.parsed_body
          expect(response_body['error']).to eq(I18n.t(
            'login.invalid_second_factor_code'
          ))
        end
      end
    end
  end

  context 'logoff support' do
    it 'can log off users cleanly' do
      user = Fabricate(:user)
      sign_in(user)

      UserAuthToken.destroy_all

      # we need a route that will call current user
      post '/drafts.json', params: {}
      expect(response.headers['Discourse-Logged-Out']).to eq("1")
    end
  end

  describe '#become' do
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

  describe '#sso' do
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

  describe '#sso_login' do
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

    it 'does not create superfluous auth tokens when already logged in' do
      user = Fabricate(:user)
      sign_in(user)

      sso = get_sso("/")
      sso.email = user.email
      sso.external_id = 'abc'
      sso.username = 'sam'

      expect do
        get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers
        logged_on_user = Discourse.current_user_provider.new(request.env).current_user
        expect(logged_on_user.id).to eq(user.id)
      end.not_to change { UserAuthToken.count }

    end

    it 'will never redirect back to /session/sso path' do
      sso = get_sso("/session/sso?bla=1")
      sso.email = user.email
      sso.external_id = 'abc'
      sso.username = 'sam'

      get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers
      expect(response).to redirect_to('/')

      sso = get_sso("http://#{Discourse.current_hostname}/session/sso?bla=1")
      sso.email = user.email
      sso.external_id = 'abc'
      sso.username = 'sam'

      get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers
      expect(response).to redirect_to('/')

    end

    it 'can handle invalid sso external ids due to blank' do
      sso = get_sso("/")
      sso.email = "test@test.com"
      sso.external_id = '   '
      sso.username = 'sam'

      messages = track_log_messages(level: Logger::WARN) do
        get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers
      end

      expect(messages.length).to eq(0)
      expect(response.status).to eq(500)
      expect(response.body).to include(I18n.t('discourse_connect.blank_id_error'))
    end

    it 'can handle invalid sso email validation errors' do
      SiteSetting.blocked_email_domains = "test.com"
      sso = get_sso("/")
      sso.email = "test@test.com"
      sso.external_id = '123'
      sso.username = 'sam'

      messages = track_log_messages(level: Logger::WARN) do
        get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers
      end

      expect(messages.length).to eq(0)
      expect(response.status).to eq(500)
      expect(response.body).to include(I18n.t("discourse_connect.email_error", email: ERB::Util.html_escape("test@test.com")))
    end

    it 'can handle invalid sso external ids due to banned word' do
      sso = get_sso("/")
      sso.email = "test@test.com"
      sso.external_id = 'nil'
      sso.username = 'sam'

      get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers

      expect(response.status).to eq(500)
    end

    it 'can take over an account' do
      user = Fabricate(:user, email: 'bill@bill.com')

      sso = get_sso("/")
      sso.email = user.email
      sso.external_id = 'abc'
      sso.username = 'sam'

      get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers

      expect(response).to redirect_to('/')
      logged_on_user = Discourse.current_user_provider.new(request.env).current_user
      expect(logged_on_user.email).to eq(user.email)
      expect(logged_on_user.single_sign_on_record.external_id).to eq("abc")
      expect(logged_on_user.single_sign_on_record.external_username).to eq('sam')

      # we are updating the email ... ensure auto group membership works

      sign_out

      SiteSetting.email_editable = false
      SiteSetting.auth_overrides_email = true

      group = Fabricate(:group, name: :bob, automatic_membership_email_domains: 'jane.com')
      sso = get_sso("/")
      sso.email = "hello@jane.com"
      sso.external_id = 'abc'

      get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers

      logged_on_user = Discourse.current_user_provider.new(request.env).current_user

      expect(logged_on_user.email).to eq('hello@jane.com')
      expect(group.users.count).to eq(1)
    end

    def sso_for_ip_specs
      sso = get_sso('/a/')
      sso.external_id = '666'
      sso.email = 'bob@bob.com'
      sso.name = 'Sam Saffron'
      sso.username = 'sam'
      sso
    end

    it 'respects IP restrictions on create' do
      ScreenedIpAddress.all.destroy_all
      get "/"
      _screened_ip = Fabricate(:screened_ip_address, ip_address: request.remote_ip, action_type: ScreenedIpAddress.actions[:block])

      sso = sso_for_ip_specs
      get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers

      logged_on_user = Discourse.current_user_provider.new(request.env).current_user
      expect(logged_on_user).to eq(nil)
    end

    it 'respects IP restrictions on login' do
      ScreenedIpAddress.all.destroy_all
      get "/"
      sso = sso_for_ip_specs
      DiscourseConnect.parse(sso.payload, secure_session: read_secure_session).lookup_or_create_user(request.remote_ip)

      sso = sso_for_ip_specs
      _screened_ip = Fabricate(:screened_ip_address, ip_address: request.remote_ip, action_type: ScreenedIpAddress.actions[:block])

      get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers
      logged_on_user = Discourse.current_user_provider.new(request.env).current_user
      expect(logged_on_user).to be_blank
    end

    it 'respects email restrictions' do
      sso = get_sso('/a/')
      sso.external_id = '666'
      sso.email = 'bob@bob.com'
      sso.name = 'Sam Saffron'
      sso.username = 'sam'

      ScreenedEmail.block('bob@bob.com')
      get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers

      logged_on_user = Discourse.current_user_provider.new(request.env).current_user
      expect(logged_on_user).to eq(nil)
    end

    it 'allows you to create an admin account' do
      sso = get_sso('/a/')
      sso.external_id = '666'
      sso.email = 'bob@bob.com'
      sso.name = 'Sam Saffron'
      sso.username = 'sam'
      sso.custom_fields["shop_url"] = "http://my_shop.com"
      sso.custom_fields["shop_name"] = "Sam"
      sso.admin = true

      get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers

      logged_on_user = Discourse.current_user_provider.new(request.env).current_user
      expect(logged_on_user.admin).to eq(true)
    end

    it 'does not redirect offsite' do
      sso = get_sso("#{Discourse.base_url}//site.com/xyz")
      sso.external_id = '666'
      sso.email = 'bob@bob.com'
      sso.name = 'Sam Saffron'
      sso.username = 'sam'

      get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers
      expect(response).to redirect_to("#{Discourse.base_url}//site.com/xyz")
    end

    it 'redirects to a non-relative url' do
      sso = get_sso("#{Discourse.base_url}/b/")
      sso.external_id = '666'
      sso.email = 'bob@bob.com'
      sso.name = 'Sam Saffron'
      sso.username = 'sam'

      get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers
      expect(response).to redirect_to('/b/')
    end

    it 'redirects to random url if it is allowed' do
      SiteSetting.discourse_connect_allows_all_return_paths = true

      sso = get_sso('https://gusundtrout.com')
      sso.external_id = '666'
      sso.email = 'bob@bob.com'
      sso.name = 'Sam Saffron'
      sso.username = 'sam'

      get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers
      expect(response).to redirect_to('https://gusundtrout.com')
    end

    it 'redirects to root if the host of the return_path is different' do
      sso = get_sso('//eviltrout.com')
      sso.external_id = '666'
      sso.email = 'bob@bob.com'
      sso.name = 'Sam Saffron'
      sso.username = 'sam'

      get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers
      expect(response).to redirect_to('/')
    end

    it 'redirects to root if the host of the return_path is different' do
      sso = get_sso('http://eviltrout.com')
      sso.external_id = '666'
      sso.email = 'bob@bob.com'
      sso.name = 'Sam Saffron'
      sso.username = 'sam'

      get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers
      expect(response).to redirect_to('/')
    end

    it 'allows you to create an account' do
      group = Fabricate(:group, name: :bob, automatic_membership_email_domains: 'bob.com')

      sso = get_sso('/a/')
      sso.external_id = '666'
      sso.email = 'bob@bob.com'
      sso.name = 'Sam Saffron'
      sso.username = 'sam'
      sso.custom_fields["shop_url"] = "http://my_shop.com"
      sso.custom_fields["shop_name"] = "Sam"

      events = DiscourseEvent.track_events do
        get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers
      end

      expect(events.map { |event| event[:event_name] }).to include(
       :user_logged_in, :user_first_logged_in
      )

      expect(response).to redirect_to('/a/')

      logged_on_user = Discourse.current_user_provider.new(request.env).current_user

      expect(group.users.where(id: logged_on_user.id).count).to eq(1)

      # ensure nothing is transient
      logged_on_user = User.find(logged_on_user.id)

      expect(logged_on_user.admin).to eq(false)
      expect(logged_on_user.email).to eq('bob@bob.com')
      expect(logged_on_user.name).to eq('Sam Saffron')
      expect(logged_on_user.username).to eq('sam')

      expect(logged_on_user.single_sign_on_record.external_id).to eq("666")
      expect(logged_on_user.single_sign_on_record.external_username).to eq('sam')
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
        expect(response.body).to include(I18n.t("invite.not_found_template", site_name: SiteSetting.title, base_url: Discourse.base_url))
        expect(invite.reload.redeemed?).to eq(true)
        expect(User.find_by_email("bob@bob.com")).to eq(nil)
      end

      it "errors if the invite is for a specific email and that email does not match the sso email" do
        invite.update!(email: "someotheremail@dave.com")
        login_with_sso_and_invite
        expect(response.status).to eq(400)
        expect(response.body).to include(I18n.t("invite.not_matching_email", base_url: Discourse.base_url))
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

      it "allows you to create an account and redeems the invite successfully even if must_approve_users is enabled" do
        SiteSetting.must_approve_users = true

        login_with_sso_and_invite

        expect(response.status).to eq(302)
        expect(response).to redirect_to("/")
        expect(invite.reload.redeemed?).to eq(true)

        user = User.find_by_email("bob@bob.com")
        expect(user.active).to eq(true)
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

    context 'when sso emails are not trusted' do
      context 'if you have not activated your account' do
        it 'does not log you in' do
          sso = get_sso('/a/')
          sso.external_id = '666'
          sso.email = 'bob@bob.com'
          sso.name = 'Sam Saffron'
          sso.username = 'sam'
          sso.require_activation = true

          get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers

          logged_on_user = Discourse.current_user_provider.new(request.env).current_user
          expect(logged_on_user).to eq(nil)
        end

        it 'sends an activation email' do
          sso = get_sso('/a/')
          sso.external_id = '666'
          sso.email = 'bob@bob.com'
          sso.name = 'Sam Saffron'
          sso.username = 'sam'
          sso.require_activation = true

          get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers
          expect(Jobs::CriticalUserEmail.jobs.size).to eq(1)
        end
      end

      context 'if you have activated your account' do
        it 'allows you to log in' do
          sso = get_sso('/hello/world')
          sso.external_id = '997'
          sso.sso_url = "http://somewhere.over.com/sso_login"
          sso.require_activation = true

          user = Fabricate(:user)
          user.create_single_sign_on_record(external_id: '997', last_payload: '')
          user.stubs(:active?).returns(true)

          get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers

          logged_on_user = Discourse.current_user_provider.new(request.env).current_user
          expect(user.id).to eq(logged_on_user.id)
        end
      end
    end

    it 'allows login to existing account with valid nonce' do
      sso = get_sso('/hello/world')
      sso.external_id = '997'
      sso.sso_url = "http://somewhere.over.com/sso_login"

      user = Fabricate(:user)
      user.create_single_sign_on_record(external_id: '997', last_payload: '')

      get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers

      user.single_sign_on_record.reload
      expect(user.single_sign_on_record.last_payload).to eq(sso.unsigned_payload)

      expect(response).to redirect_to('/hello/world')
      logged_on_user = Discourse.current_user_provider.new(request.env).current_user

      expect(user.id).to eq(logged_on_user.id)

      # nonce is bad now
      get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers
      expect(response.status).to eq(419)
    end

    it 'associates the nonce with the current session' do
      sso = get_sso('/hello/world')
      sso.external_id = '997'
      sso.sso_url = "http://somewhere.over.com/sso_login"

      user = Fabricate(:user)
      user.create_single_sign_on_record(external_id: '997', last_payload: '')

      # Establish a fresh session
      cookies.to_hash.keys.each { |k| cookies.delete(k) }

      get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers
      expect(response.status).to eq(419)
    end

    context "when sso provider is enabled" do
      before do
        SiteSetting.enable_discourse_connect_provider = true
        SiteSetting.discourse_connect_provider_secrets = [
          "*|secret,forAll",
          "*.rainbow|wrongSecretForOverRainbow",
          "www.random.site|secretForRandomSite",
          "somewhere.over.rainbow|secretForOverRainbow",
        ].join("\n")
      end

      it "doesn't break" do
        sso = get_sso('/hello/world')
        sso.external_id = '997'
        sso.sso_url = "http://somewhere.over.com/sso_login"
        sso.return_sso_url = "http://someurl.com"

        user = Fabricate(:user)
        user.create_single_sign_on_record(external_id: '997', last_payload: '')

        get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers

        user.single_sign_on_record.reload
        expect(user.single_sign_on_record.last_payload).to eq(sso.unsigned_payload)

        expect(response).to redirect_to('/hello/world')
        logged_on_user = Discourse.current_user_provider.new(request.env).current_user

        expect(user.id).to eq(logged_on_user.id)
      end
    end

    it 'returns the correct error code for invalid signature' do
      sso = get_sso('/hello/world')
      sso.external_id = '997'
      sso.sso_url = "http://somewhere.over.com/sso_login"

      correct_params = Rack::Utils.parse_query(sso.payload)
      get "/session/sso_login", params: correct_params.merge("sig": "thisisnotthesigyouarelookingfor"), headers: headers
      expect(response.status).to eq(422)
      expect(response.body).not_to include(correct_params["sig"]) # Check we didn't send the real sig back to the client
      logged_on_user = Discourse.current_user_provider.new(request.env).current_user
      expect(logged_on_user).to eq(nil)

      correct_params = Rack::Utils.parse_query(sso.payload)
      get "/session/sso_login", params: correct_params.merge("sig": "thisisasignaturewith@special!characters"), headers: headers
      expect(response.status).to eq(422)
      expect(response.body).not_to include(correct_params["sig"]) # Check we didn't send the real sig back to the client
      logged_on_user = Discourse.current_user_provider.new(request.env).current_user
      expect(logged_on_user).to eq(nil)
    end

    describe 'local attribute override from SSO payload' do
      before do
        SiteSetting.email_editable = false
        SiteSetting.auth_overrides_email = true
        SiteSetting.auth_overrides_username = true
        SiteSetting.auth_overrides_name = true

        @user = Fabricate(:user)

        @sso = get_sso('/hello/world')
        @sso.external_id = '997'

        @reversed_username = @user.username.reverse
        @sso.username = @reversed_username
        @sso.email = "#{@reversed_username}@garbage.org"
        @reversed_name = @user.name.reverse
        @sso.name = @reversed_name

        @suggested_username = UserNameSuggester.suggest(@sso.username || @sso.name || @sso.email)
        @suggested_name = User.suggest_name(@sso.name || @sso.username || @sso.email)
        @user.create_single_sign_on_record(external_id: '997', last_payload: '')
      end

      it 'stores the external attributes' do
        get "/session/sso_login", params: Rack::Utils.parse_query(@sso.payload), headers: headers
        @user.single_sign_on_record.reload
        expect(@user.single_sign_on_record.external_username).to eq(@sso.username)
        expect(@user.single_sign_on_record.external_email).to eq(@sso.email)
        expect(@user.single_sign_on_record.external_name).to eq(@sso.name)
      end

      it 'overrides attributes' do
        get "/session/sso_login", params: Rack::Utils.parse_query(@sso.payload), headers: headers

        logged_on_user = Discourse.current_user_provider.new(request.env).current_user
        expect(logged_on_user.username).to eq(@suggested_username)
        expect(logged_on_user.email).to eq("#{@reversed_username}@garbage.org")
        expect(logged_on_user.name).to eq(@sso.name)
      end

      it 'does not change matching attributes for an existing account' do
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
  end

  describe '#sso_provider' do
    let(:headers) { { host: Discourse.current_hostname } }

    describe 'can act as an SSO provider' do
      let(:logo_fixture) { "http://#{Discourse.current_hostname}/uploads/logo.png" }

      before do
        stub_request(:any, /#{Discourse.current_hostname}\/uploads/).to_return(
          status: 200,
          body: lambda { |request| file_from_fixtures("logo.png") }
        )

        SiteSetting.enable_discourse_connect_provider = true
        SiteSetting.enable_discourse_connect = false
        SiteSetting.enable_local_logins = true
        SiteSetting.discourse_connect_provider_secrets = [
          "*|secret,forAll",
          "*.rainbow|wrongSecretForOverRainbow",
          "www.random.site|secretForRandomSite",
          "somewhere.over.rainbow|secretForOverRainbow",
        ].join("\n")

        @sso = DiscourseConnectProvider.new
        @sso.nonce = "mynonce"
        @sso.return_sso_url = "http://somewhere.over.rainbow/sso"

        @user = Fabricate(:user, password: "myfrogs123ADMIN", active: true, admin: true)
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

      it "successfully logs in and redirects user to return_sso_url when the user is not logged in" do
        get "/session/sso_provider", params: Rack::Utils.parse_query(@sso.payload("secretForOverRainbow"))

        expect(response).to redirect_to("/login")

        post "/session.json",
          params: { login: @user.username, password: "myfrogs123ADMIN" }, xhr: true, headers: headers

        location = response.cookies["sso_destination_url"]
        # javascript code will handle redirection of user to return_sso_url
        expect(location).to match(/^http:\/\/somewhere.over.rainbow\/sso/)

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
      end

      it "it fails to log in if secret is wrong" do
        get "/session/sso_provider", params: Rack::Utils.parse_query(@sso.payload("secretForRandomSite"))

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
        sso = DiscourseConnectProvider.new
        get "/session/sso_provider?sso=asdf&sig=abcdefghij"
        expect(response.status).to eq(422)
      end

      it "successfully redirects user to return_sso_url when the user is logged in" do
        sign_in(@user)

        get "/session/sso_provider", params: Rack::Utils.parse_query(@sso.payload("secretForOverRainbow"))

        location = response.header["Location"]
        expect(location).to match(/^http:\/\/somewhere.over.rainbow\/sso/)

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
      end

      it 'handles non local content correctly' do
        SiteSetting.avatar_sizes = "100|49"
        setup_s3
        SiteSetting.s3_cdn_url = "http://cdn.com"

        stub_request(:any, /s3-upload-bucket.s3.dualstack.us-west-1.amazonaws.com/).to_return(status: 200, body: "", headers: { referer: "fgdfds" })

        @user.create_user_avatar!
        upload = Fabricate(:upload, url: "//s3-upload-bucket.s3.dualstack.us-west-1.amazonaws.com/something")

        Fabricate(:optimized_image,
          sha1: SecureRandom.hex << "A" * 8,
          upload: upload,
          width: 98,
          height: 98,
          url: "//s3-upload-bucket.s3.amazonaws.com/something/else"
        )

        @user.update_columns(uploaded_avatar_id: upload.id)

        upload1 = Fabricate(:upload_s3)
        upload2 = Fabricate(:upload_s3)

        @user.user_profile.update!(
          profile_background_upload: upload1,
          card_background_upload: upload2
        )

        @user.reload
        @user.user_avatar.reload
        @user.user_profile.reload

        sign_in(@user)

        stub_request(:get, "http://cdn.com/something/else").to_return(
          body: lambda { |request| File.new(Rails.root + 'spec/fixtures/images/logo.png') }
        )

        get "/session/sso_provider", params: Rack::Utils.parse_query(@sso.payload("secretForOverRainbow"))

        location = response.header["Location"]
        # javascript code will handle redirection of user to return_sso_url
        expect(location).to match(/^http:\/\/somewhere.over.rainbow\/sso/)

        payload = location.split("?")[1]
        sso2 = DiscourseConnectProvider.parse(payload)

        expect(sso2.avatar_url.blank?).to_not eq(true)
        expect(sso2.profile_background_url.blank?).to_not eq(true)
        expect(sso2.card_background_url.blank?).to_not eq(true)

        expect(sso2.avatar_url).to start_with("#{SiteSetting.s3_cdn_url}/original")
        expect(sso2.profile_background_url).to start_with(SiteSetting.s3_cdn_url)
        expect(sso2.card_background_url).to start_with(SiteSetting.s3_cdn_url)
      end

      it "successfully logs out and redirects user to return_sso_url when the user is logged in" do
        sign_in(@user)

        @sso.logout = true
        get "/session/sso_provider", params: Rack::Utils.parse_query(@sso.payload("secretForOverRainbow"))

        location = response.header["Location"]
        expect(location).to match(/^http:\/\/somewhere.over.rainbow\/sso$/)

        expect(response.status).to eq(302)
        expect(session[:current_user_id]).to be_blank
        expect(response.cookies["_t"]).to be_blank
      end

      it "successfully logs out and redirects user to return_sso_url when the user is not logged in" do
        @sso.logout = true
        get "/session/sso_provider", params: Rack::Utils.parse_query(@sso.payload("secretForOverRainbow"))

        location = response.header["Location"]
        expect(location).to match(/^http:\/\/somewhere.over.rainbow\/sso$/)

        expect(response.status).to eq(302)
        expect(session[:current_user_id]).to be_blank
        expect(response.cookies["_t"]).to be_blank
      end
    end
  end

  describe '#create' do
    context 'local login is disabled' do
      before do
        SiteSetting.enable_local_logins = false

        post "/session.json", params: {
          login: user.username, password: 'myawesomepassword'
        }
      end
      it_behaves_like "failed to continue local login"
    end

    context 'SSO is enabled' do
      before do
        SiteSetting.discourse_connect_url = "https://www.example.com/sso"
        SiteSetting.enable_discourse_connect = true

        post "/session.json", params: {
          login: user.username, password: 'myawesomepassword'
        }
      end
      it_behaves_like "failed to continue local login"
    end

    context 'local login via email is disabled' do
      before do
        SiteSetting.enable_local_logins_via_email = false
      end
      it 'doesnt matter, logs in correctly' do
        post "/session.json", params: {
          login: user.username, password: 'myawesomepassword'
        }
        expect(response.status).to eq(200)
      end
    end

    context 'when email is confirmed' do
      before do
        EmailToken.confirm(email_token.token)
      end

      it "raises an error when the login isn't present" do
        post "/session.json"
        expect(response.status).to eq(400)
      end

      describe 'invalid password' do
        it "should return an error with an invalid password" do
          post "/session.json", params: {
            login: user.username, password: 'sssss'
          }

          expect(response.status).to eq(200)
          expect(response.parsed_body['error']).to eq(
            I18n.t("login.incorrect_username_email_or_password")
          )
        end
      end

      describe 'invalid password' do
        it "should return an error with an invalid password if too long" do
          User.any_instance.expects(:confirm_password?).never
          post "/session.json", params: {
            login: user.username, password: ('s' * (User.max_password_length + 1))
          }

          expect(response.status).to eq(200)
          expect(response.parsed_body['error']).to eq(
            I18n.t("login.incorrect_username_email_or_password")
          )
        end
      end

      describe 'suspended user' do
        it 'should return an error' do
          user.suspended_till = 2.days.from_now
          user.suspended_at = Time.now
          user.save!
          StaffActionLogger.new(user).log_user_suspend(user, "<strike>banned</strike>")

          post "/session.json", params: {
            login: user.username, password: 'myawesomepassword'
          }

          expected_message = I18n.t('login.suspended_with_reason',
                                    date: I18n.l(user.suspended_till, format: :date_only),
                                    reason: Rack::Utils.escape_html(user.suspend_reason))
          expect(response.status).to eq(200)
          expect(response.parsed_body['error']).to eq(expected_message)
        end

        it 'when suspended forever should return an error without suspended till date' do
          user.suspended_till = 101.years.from_now
          user.suspended_at = Time.now
          user.save!
          StaffActionLogger.new(user).log_user_suspend(user, "<strike>banned</strike>")

          post "/session.json", params: {
            login: user.username, password: 'myawesomepassword'
          }

          expected_message = I18n.t('login.suspended_with_reason_forever', reason: Rack::Utils.escape_html(user.suspend_reason))
          expect(response.parsed_body['error']).to eq(expected_message)
        end
      end

      describe 'deactivated user' do
        it 'should return an error' do
          user.active = false
          user.save!

          post "/session.json", params: {
            login: user.username, password: 'myawesomepassword'
          }

          expect(response.status).to eq(200)
          expect(response.parsed_body['error']).to eq(I18n.t('login.not_activated'))
        end
      end

      describe 'success by username' do
        it 'logs in correctly' do
          events = DiscourseEvent.track_events do
            post "/session.json", params: {
              login: user.username, password: 'myawesomepassword'
            }
          end

          expect(response.status).to eq(200)
          expect(events.map { |event| event[:event_name] }).to contain_exactly(
            :user_logged_in, :user_first_logged_in
          )

          user.reload

          expect(session[:current_user_id]).to eq(user.id)
          expect(user.user_auth_tokens.count).to eq(1)
          unhashed_token = decrypt_auth_cookie(cookies[:_t])[:token]
          expect(UserAuthToken.hash_token(unhashed_token)).to eq(user.user_auth_tokens.first.auth_token)
        end

        context "when timezone param is provided" do
          it "sets the user_option timezone for the user" do
            post "/session.json", params: {
              login: user.username, password: 'myawesomepassword', timezone: "Australia/Melbourne"
            }
            expect(response.status).to eq(200)
            expect(user.reload.user_option.timezone).to eq("Australia/Melbourne")
          end
        end
      end

      context "when a user has security key-only 2FA login" do
        let!(:user_security_key) do
          Fabricate(
            :user_security_key,
            user: user,
            credential_id: valid_security_key_data[:credential_id],
            public_key: valid_security_key_data[:public_key]
          )
        end

        before do
          simulate_localhost_webauthn_challenge

          # store challenge in secure session by failing login once
          post "/session.json", params: {
            login: user.username,
            password: 'myawesomepassword'
          }
        end

        context "when the security key params are blank and a random second factor token is provided" do
          it "shows an error message and denies login" do

            post "/session.json", params: {
              login: user.username,
              password: 'myawesomepassword',
              second_factor_token: '99999999',
              second_factor_method: UserSecondFactor.methods[:security_key]
            }

            expect(response.status).to eq(200)
            expect(session[:current_user_id]).to eq(nil)
            response_body = response.parsed_body
            expect(response_body["failed"]).to eq("FAILED")
            expect(response_body['error']).to eq(I18n.t(
              'login.invalid_security_key'
            ))
          end
        end

        context "when the security key params are invalid" do
          it "shows an error message and denies login" do

            post "/session.json", params: {
              login: user.username,
              password: 'myawesomepassword',
              second_factor_token: {
                signature: 'bad_sig',
                clientData: 'bad_clientData',
                credentialId: 'bad_credential_id',
                authenticatorData: 'bad_authenticator_data'
              },
              second_factor_method: UserSecondFactor.methods[:security_key]
            }

            expect(response.status).to eq(200)
            expect(session[:current_user_id]).to eq(nil)
            response_body = response.parsed_body
            expect(response_body["failed"]).to eq("FAILED")
            expect(response_body['error']).to eq(I18n.t(
              'webauthn.validation.not_found_error'
            ))
          end
        end

        context "when the security key params are valid" do
          it "logs the user in" do
            post "/session.json", params: {
              login: user.username,
              password: 'myawesomepassword',
              second_factor_token: valid_security_key_auth_post_data,
              second_factor_method: UserSecondFactor.methods[:security_key]
            }

            expect(response.status).to eq(200)
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
            post "/session.json", params: {
              login: user.username,
              password: 'myawesomepassword',
              second_factor_token: valid_security_key_auth_post_data,
              second_factor_method: UserSecondFactor.methods[:security_key]
            }

            expect(response.status).to eq(200)
            expect(session[:current_user_id]).to eq(nil)
            response_body = response.parsed_body
            expect(response_body["failed"]).to eq("FAILED")
            expect(response.parsed_body['error']).to eq(I18n.t(
              'login.not_enabled_second_factor_method'
            ))
          end
        end
      end

      context 'when user has TOTP-only 2FA login' do
        let!(:user_second_factor) { Fabricate(:user_second_factor_totp, user: user) }
        let!(:user_second_factor_backup) { Fabricate(:user_second_factor_backup, user: user) }

        describe 'when second factor token is missing' do
          it 'should return the right response' do
            post "/session.json", params: {
              login: user.username,
              password: 'myawesomepassword'
            }

            expect(response.status).to eq(200)
            expect(response.parsed_body['error']).to eq(I18n.t(
              'login.invalid_second_factor_method'
            ))
          end
        end

        describe 'when second factor token is invalid' do
          context 'when using totp method' do
            it 'should return the right response' do
              post "/session.json", params: {
                login: user.username,
                password: 'myawesomepassword',
                second_factor_token: '00000000',
                second_factor_method: UserSecondFactor.methods[:totp]
              }

              expect(response.status).to eq(200)
              expect(response.parsed_body['error']).to eq(I18n.t(
                'login.invalid_second_factor_code'
              ))
            end
          end

          context 'when using backup code method' do
            it 'should return the right response' do
              post "/session.json", params: {
                login: user.username,
                password: 'myawesomepassword',
                second_factor_token: '00000000',
                second_factor_method: UserSecondFactor.methods[:backup_codes]
              }

              expect(response.status).to eq(200)
              expect(response.parsed_body['error']).to eq(I18n.t(
                'login.invalid_second_factor_code'
              ))
            end
          end
        end

        describe 'when second factor token is valid' do
          context 'when using totp method' do
            it 'should log the user in' do
              post "/session.json", params: {
                login: user.username,
                password: 'myawesomepassword',
                second_factor_token: ROTP::TOTP.new(user_second_factor.data).now,
                second_factor_method: UserSecondFactor.methods[:totp]
              }
              expect(response.status).to eq(200)
              user.reload

              expect(session[:current_user_id]).to eq(user.id)
              expect(user.user_auth_tokens.count).to eq(1)

              unhashed_token = decrypt_auth_cookie(cookies[:_t])[:token]
              expect(UserAuthToken.hash_token(unhashed_token))
                .to eq(user.user_auth_tokens.first.auth_token)
            end
          end

          context 'when using backup code method' do
            it 'should log the user in' do
              post "/session.json", params: {
                login: user.username,
                password: 'myawesomepassword',
                second_factor_token: 'iAmValidBackupCode',
                second_factor_method: UserSecondFactor.methods[:backup_codes]
              }
              expect(response.status).to eq(200)
              user.reload

              expect(session[:current_user_id]).to eq(user.id)
              expect(user.user_auth_tokens.count).to eq(1)

              unhashed_token = decrypt_auth_cookie(cookies[:_t])[:token]
              expect(UserAuthToken.hash_token(unhashed_token))
                .to eq(user.user_auth_tokens.first.auth_token)
            end
          end
        end
      end

      describe 'with a blocked IP' do
        it "doesn't log in" do
          ScreenedIpAddress.all.destroy_all
          get "/"
          _screened_ip = Fabricate(:screened_ip_address, ip_address: request.remote_ip)
          post "/session.json", params: {
            login: "@" + user.username, password: 'myawesomepassword'
          }
          expect(response.status).to eq(200)
          user.reload

          expect(session[:current_user_id]).to be_nil
        end
      end

      describe 'strips leading @ symbol' do
        it 'sets a session id' do
          post "/session.json", params: {
            login: "@" + user.username, password: 'myawesomepassword'
          }
          expect(response.status).to eq(200)
          user.reload

          expect(session[:current_user_id]).to eq(user.id)
        end
      end

      describe 'also allow login by email' do
        it 'sets a session id' do
          post "/session.json", params: {
            login: user.email, password: 'myawesomepassword'
          }
          expect(response.status).to eq(200)
          expect(session[:current_user_id]).to eq(user.id)
        end
      end

      context 'login has leading and trailing space' do
        let(:username) { " #{user.username} " }
        let(:email) { " #{user.email} " }

        it "strips spaces from the username" do
          post "/session.json", params: {
            login: username, password: 'myawesomepassword'
          }
          expect(response.status).to eq(200)
          expect(response.parsed_body['error']).not_to be_present
        end

        it "strips spaces from the email" do
          post "/session.json", params: {
            login: email, password: 'myawesomepassword'
          }
          expect(response.status).to eq(200)
          expect(response.parsed_body['error']).not_to be_present
        end
      end

      describe "when the site requires approval of users" do
        before do
          SiteSetting.must_approve_users = true
        end

        context 'with an unapproved user' do
          before do
            user.update_columns(approved: false)
            post "/session.json", params: {
              login: user.email, password: 'myawesomepassword'
            }
          end

          it "doesn't log in the user" do
            expect(response.status).to eq(200)
            expect(session[:current_user_id]).to be_blank
          end

          it "shows the 'not approved' error message" do
            expect(response.status).to eq(200)
            expect(response.parsed_body['error']).to eq(
              I18n.t('login.not_approved')
            )
          end
        end

        context "with an unapproved user who is an admin" do
          it 'sets a session id' do
            user.admin = true
            user.save!

            post "/session.json", params: {
              login: user.email, password: 'myawesomepassword'
            }
            expect(response.status).to eq(200)
            expect(session[:current_user_id]).to eq(user.id)
          end
        end
      end

      context 'when admins are restricted by ip address' do
        before do
          SiteSetting.use_admin_ip_allowlist = true
          ScreenedIpAddress.all.destroy_all
        end

        it 'is successful for admin at the ip address' do
          get "/"
          Fabricate(:screened_ip_address, ip_address: request.remote_ip, action_type: ScreenedIpAddress.actions[:allow_admin])

          user.admin = true
          user.save!

          post "/session.json", params: {
            login: user.username, password: 'myawesomepassword'
          }
          expect(response.status).to eq(200)
          expect(session[:current_user_id]).to eq(user.id)
        end

        it 'returns an error for admin not at the ip address' do
          Fabricate(:screened_ip_address, ip_address: "111.234.23.11", action_type: ScreenedIpAddress.actions[:allow_admin])
          user.admin = true
          user.save!

          post "/session.json", params: {
            login: user.username, password: 'myawesomepassword'
          }

          expect(response.status).to eq(200)
          expect(response.parsed_body['error']).to be_present
          expect(session[:current_user_id]).not_to eq(user.id)
        end

        it 'is successful for non-admin not at the ip address' do
          Fabricate(:screened_ip_address, ip_address: "111.234.23.11", action_type: ScreenedIpAddress.actions[:allow_admin])
          user.admin = false
          user.save!

          post "/session.json", params: {
            login: user.username, password: 'myawesomepassword'
          }

          expect(response.status).to eq(200)
          expect(session[:current_user_id]).to eq(user.id)
        end
      end
    end

    context 'when email has not been confirmed' do
      def post_login
        post "/session.json", params: {
          login: user.email, password: 'myawesomepassword'
        }
      end

      it "doesn't log in the user" do
        post_login
        expect(response.status).to eq(200)
        expect(session[:current_user_id]).to be_blank
      end

      it "shows the 'not activated' error message" do
        post_login
        expect(response.status).to eq(200)
        expect(response.parsed_body['error']).to eq(
          I18n.t 'login.not_activated'
        )
      end

      context "and the 'must approve users' site setting is enabled" do
        before { SiteSetting.must_approve_users = true }

        it "shows the 'not approved' error message" do
          post_login
          expect(response.status).to eq(200)
          expect(response.parsed_body['error']).to eq(
            I18n.t 'login.not_approved'
          )
        end
      end
    end

    context 'rate limited' do
      it 'rate limits login' do
        SiteSetting.max_logins_per_ip_per_hour = 2
        RateLimiter.enable
        RateLimiter.clear_all!

        2.times do
          post "/session.json", params: {
            login: user.username, password: 'myawesomepassword'
          }

          expect(response.status).to eq(200)
        end

        post "/session.json", params: {
          login: user.username, password: 'myawesomepassword'
        }

        expect(response.status).to eq(429)
        json = response.parsed_body
        expect(json["error_type"]).to eq("rate_limit")
      end

      it 'rate limits second factor attempts by IP' do
        RateLimiter.enable
        RateLimiter.clear_all!

        6.times do |x|
          post "/session.json", params: {
            login: "#{user.username}#{x}",
            password: 'myawesomepassword',
            second_factor_token: '000000',
            second_factor_method: UserSecondFactor.methods[:totp]
          }
          expect(response.status).to eq(200)
        end

        post "/session.json", params: {
          login: user.username,
          password: 'myawesomepassword',
          second_factor_token: '000000',
          second_factor_method: UserSecondFactor.methods[:totp]
        }

        expect(response.status).to eq(429)
        json = response.parsed_body
        expect(json["error_type"]).to eq("rate_limit")
      end

      it 'rate limits second factor attempts by login' do
        RateLimiter.enable
        RateLimiter.clear_all!

        6.times do |x|
          post "/session.json", params: {
            login: user.username,
            password: 'myawesomepassword',
            second_factor_token: '000000',
            second_factor_method: UserSecondFactor.methods[:totp]
          }, env: { "REMOTE_ADDR": "1.2.3.#{x}" }

          expect(response.status).to eq(200)
        end

        [user.username + " ", user.username.capitalize, user.username].each_with_index do |username , x|
          post "/session.json", params: {
            login: username,
            password: 'myawesomepassword',
            second_factor_token: '000000',
            second_factor_method: UserSecondFactor.methods[:totp]
          }, env: { "REMOTE_ADDR": "1.2.4.#{x}" }

          expect(response.status).to eq(429)
          json = response.parsed_body
          expect(json["error_type"]).to eq("rate_limit")
        end
      end
    end
  end

  describe '#destroy' do
    it 'removes the session variable and the auth token cookies' do
      user = sign_in(Fabricate(:user))
      delete "/session/#{user.username}.json"

      expect(response.status).to eq(302)
      expect(session[:current_user_id]).to be_blank
      expect(response.cookies["_t"]).to be_blank
    end

    it 'returns the redirect URL in the body for XHR requests' do
      user = sign_in(Fabricate(:user))
      delete "/session/#{user.username}.json", xhr: true

      expect(response.status).to eq(200)
      expect(session[:current_user_id]).to be_blank
      expect(response.cookies["_t"]).to be_blank

      expect(response.parsed_body["redirect_url"]).to eq("/")
    end

    it 'redirects to /login when SSO and login_required' do
      SiteSetting.discourse_connect_url = "https://example.com/sso"
      SiteSetting.enable_discourse_connect = true

      user = sign_in(Fabricate(:user))
      delete "/session/#{user.username}.json", xhr: true
      expect(response.status).to eq(200)
      expect(response.parsed_body["redirect_url"]).to eq("/")

      SiteSetting.login_required = true
      user = sign_in(Fabricate(:user))
      delete "/session/#{user.username}.json", xhr: true
      expect(response.status).to eq(200)
      expect(response.parsed_body["redirect_url"]).to eq("/login")
    end

    it 'allows plugins to manipulate redirect URL' do
      callback = -> (data) do
        data[:redirect_url] = "/myredirect/#{data[:user].username}"
      end

      DiscourseEvent.on(:before_session_destroy, &callback)

      user = sign_in(Fabricate(:user))
      delete "/session/#{user.username}.json", xhr: true

      expect(response.status).to eq(200)
      expect(response.parsed_body["redirect_url"]).to eq("/myredirect/#{user.username}")
    ensure
      DiscourseEvent.off(:before_session_destroy, &callback)
    end
  end

  describe '#one_time_password' do
    context 'missing token' do
      it 'returns the right response' do
        get "/session/otp"
        expect(response.status).to eq(404)
      end
    end

    context 'invalid token' do
      it 'returns the right response' do
        get "/session/otp/asd1231dasd123"

        expect(response.status).to eq(404)

        post "/session/otp/asd1231dasd123"

        expect(response.status).to eq(404)
      end

      context 'when token is valid' do
        it "should display the form for GET" do
          token = SecureRandom.hex
          Discourse.redis.setex "otp_#{token}", 10.minutes, user.username

          get "/session/otp/#{token}"

          expect(response.status).to eq(200)
          expect(response.body).to include(
            I18n.t("user_api_key.otp_confirmation.logging_in_as", username: user.username)
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

        it 'should authenticate user and delete token' do
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
        end
      end
    end

  end

  describe '#forgot_password' do

    context 'when hide_email_address_taken is set' do
      before do
        SiteSetting.hide_email_address_taken = true
      end

      it 'denies for username' do
        post "/session/forgot_password.json",
          params: { login: user.username }

        expect(response.status).to eq(400)
        expect(Jobs::CriticalUserEmail.jobs.size).to eq(0)
      end

      it 'allows for username when staff' do
        sign_in(Fabricate(:admin))

        post "/session/forgot_password.json",
          params: { login: user.username }

        expect(response.status).to eq(200)
        expect(Jobs::CriticalUserEmail.jobs.size).to eq(1)
      end

      it 'allows for email' do
        post "/session/forgot_password.json",
          params: { login: user.email }

        expect(response.status).to eq(200)
        expect(Jobs::CriticalUserEmail.jobs.size).to eq(1)
      end
    end

    it 'raises an error without a username parameter' do
      post "/session/forgot_password.json"
      expect(response.status).to eq(400)
    end

    it 'should correctly screen ips' do
      ScreenedIpAddress.create!(
        ip_address: '100.0.0.1',
        action_type: ScreenedIpAddress.actions[:block]
      )

      post "/session/forgot_password.json",
        params: { login: 'made_up' },
        headers: { 'REMOTE_ADDR' => '100.0.0.1'  }

      expect(response.parsed_body).to eq({
        "errors" => [I18n.t("login.reset_not_allowed_from_ip_address")]
      })

    end

    it 'should correctly rate limits' do
      RateLimiter.enable
      RateLimiter.clear_all!

      user = Fabricate(:user)

      3.times do
        post "/session/forgot_password.json", params: { login: user.username }
        expect(response.status).to eq(200)
      end

      post "/session/forgot_password.json", params: { login: user.username }
      expect(response.status).to eq(422)

      3.times do
        post "/session/forgot_password.json",
          params: { login: user.username },
          headers: { 'REMOTE_ADDR' => '10.1.1.1'  }

        expect(response.status).to eq(200)
      end

      post "/session/forgot_password.json",
        params: { login: user.username },
        headers: { 'REMOTE_ADDR' => '100.1.1.1'  }

      # not allowed, max 6 a day
      expect(response.status).to eq(422)

    end

    context 'for a non existant username' do
      it "doesn't generate a new token for a made up username" do
        expect do
          post "/session/forgot_password.json", params: { login: 'made_up' }
        end.not_to change(EmailToken, :count)
        expect(Jobs::CriticalUserEmail.jobs.size).to eq(0)
      end
    end

    context 'for an existing username' do
      fab!(:user) { Fabricate(:user) }

      context 'local login is disabled' do
        before do
          SiteSetting.enable_local_logins = false
          post "/session/forgot_password.json", params: { login: user.username }
        end
        it_behaves_like "failed to continue local login"
      end

      context 'SSO is enabled' do
        before do
          SiteSetting.discourse_connect_url = "https://www.example.com/sso"
          SiteSetting.enable_discourse_connect = true

          post "/session.json", params: {
            login: user.username, password: 'myawesomepassword'
          }
        end
        it_behaves_like "failed to continue local login"
      end

      context "local logins are disabled" do
        before do
          SiteSetting.enable_local_logins = false

          post "/session.json", params: {
            login: user.username, password: 'myawesomepassword'
          }
        end
        it_behaves_like "failed to continue local login"
      end

      context "local logins via email are disabled" do
        before do
          SiteSetting.enable_local_logins_via_email = false
        end
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

    context 'do nothing to system username' do
      let(:system) { Discourse.system_user }

      it 'generates no token for system username' do
        expect do
          post "/session/forgot_password.json", params: { login: system.username }
        end.not_to change(EmailToken, :count)
      end

      it 'enqueues no email' do
        post "/session/forgot_password.json", params: { login: system.username }
        expect(Jobs::CriticalUserEmail.jobs.size).to eq(0)
      end
    end

    context 'for a staged account' do
      let!(:staged) { Fabricate(:staged) }

      it 'generates no token for staged username' do
        expect do
          post "/session/forgot_password.json", params: { login: staged.username }
        end.not_to change(EmailToken, :count)
      end

      it 'enqueues no email' do
        post "/session/forgot_password.json", params: { login: staged.username }
        expect(Jobs::CriticalUserEmail.jobs.size).to eq(0)
      end
    end
  end

  describe '#current' do
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
        json = response.parsed_body
        expect(json['current_user']).to be_present
        expect(json['current_user']['id']).to eq(user.id)
      end
    end
  end
end
