# frozen_string_literal: true

require 'rails_helper'

describe UsersController do
  let(:user) { Fabricate(:user) }

  describe "#full account registration flow" do
    it "will correctly handle honeypot and challenge" do

      get '/u/hp.json'
      expect(response.status).to eq(200)

      json = JSON.parse(response.body)

      params = {
        email: 'jane@jane.com',
        name: 'jane',
        username: 'jane',
        password_confirmation: json['value'],
        challenge: json['challenge'].reverse,
        password: SecureRandom.hex
      }

      secure_session = SecureSession.new(session["secure_session_id"])

      expect(secure_session[UsersController::HONEYPOT_KEY]).to eq(json["value"])
      expect(secure_session[UsersController::CHALLENGE_KEY]).to eq(json["challenge"])

      post '/u.json', params: params

      expect(response.status).to eq(200)

      jane = User.find_by(username: 'jane')

      expect(jane.email).to eq('jane@jane.com')

      expect(secure_session[UsersController::HONEYPOT_KEY]).to eq(nil)
      expect(secure_session[UsersController::CHALLENGE_KEY]).to eq(nil)
    end
  end

  describe '#perform_account_activation' do
    let(:token) do
      return @token if @token.present?
      email_token = EmailToken.create!(expired: false, confirmed: false, user: user, email: user.email)
      @token = email_token.token
      @token
    end

    before do
      UsersController.any_instance.stubs(:honeypot_or_challenge_fails?).returns(false)
    end

    context 'invalid token' do
      it 'return success' do
        put "/u/activate-account/invalid-tooken"
        expect(response.status).to eq(200)
        expect(flash[:error]).to be_present
      end
    end

    context 'valid token' do
      context 'welcome message' do
        it 'enqueues a welcome message if the user object indicates so' do
          user.update(active: false)
          put "/u/activate-account/#{token}"
          expect(response.status).to eq(200)
          expect(Jobs::SendSystemMessage.jobs.size).to eq(1)
          expect(Jobs::SendSystemMessage.jobs.first["args"].first["message_type"]).to eq("welcome_user")
        end

        it "doesn't enqueue the welcome message if the object returns false" do
          user.update(active: true)
          put "/u/activate-account/#{token}"
          expect(response.status).to eq(200)
          expect(Jobs::SendSystemMessage.jobs.size).to eq(0)
        end
      end

      context "honeypot" do
        it "raises an error if the honeypot is invalid" do
          UsersController.any_instance.stubs(:honeypot_or_challenge_fails?).returns(true)
          put "/u/activate-account/#{token}"
          expect(response.status).to eq(403)
        end
      end

      context 'response' do
        before do
          Guardian.any_instance.expects(:can_access_forum?).returns(true)
          EmailToken.expects(:confirm).with("#{token}").returns(user)
        end

        it 'correctly logs on user' do
          events = DiscourseEvent.track_events do
            put "/u/activate-account/#{token}"
          end

          expect(events.map { |event| event[:event_name] }).to contain_exactly(
            :user_logged_in, :user_first_logged_in
          )

          expect(response.status).to eq(200)
          expect(flash[:error]).to be_blank
          expect(session[:current_user_id]).to be_present

          expect(CGI.unescapeHTML(response.body))
            .to_not include(I18n.t('activation.approval_required'))
        end
      end

      context 'user is not approved' do
        before do
          SiteSetting.must_approve_users = true
          EmailToken.expects(:confirm).with("#{token}").returns(user)
          put "/u/activate-account/#{token}"
        end

        it 'should return the right response' do
          expect(response.status).to eq(200)

          expect(CGI.unescapeHTML(response.body))
            .to include(I18n.t('activation.approval_required'))

          expect(response.body).to_not have_tag(:script, with: {
            src: '/assets/application.js'
          })

          expect(flash[:error]).to be_blank
          expect(session[:current_user_id]).to be_blank
        end
      end
    end

    context 'when cookies contains a destination URL' do
      it 'should redirect to the URL' do
        destination_url = 'http://thisisasite.com/somepath'
        cookies[:destination_url] = destination_url

        put "/u/activate-account/#{token}"

        expect(response).to redirect_to(destination_url)
      end
    end
  end

  describe '#password_reset' do
    fab!(:user) { Fabricate(:user) }
    let(:token) { SecureRandom.hex }

    context "you can view it even if login is required" do
      it "returns success" do
        SiteSetting.login_required = true
        get "/u/password-reset/#{token}"
        expect(response.status).to eq(200)
        expect(CGI.unescapeHTML(response.body)).to include(I18n.t('password_reset.no_token'))
      end
    end

    context 'missing token' do
      it 'disallows login' do
        get "/u/password-reset/#{token}"

        expect(response.status).to eq(200)

        expect(CGI.unescapeHTML(response.body))
          .to include(I18n.t('password_reset.no_token'))

        expect(response.body).to_not have_tag(:script, with: {
          src: '/assets/application.js'
        })

        expect(session[:current_user_id]).to be_blank
      end

      it "responds with proper error message" do
        get "/u/password-reset/#{token}.json"

        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)["message"]).to eq(I18n.t('password_reset.no_token'))
        expect(session[:current_user_id]).to be_blank
      end
    end

    context 'invalid token' do
      it 'disallows login' do
        get "/u/password-reset/ev!l_trout@!"

        expect(response.status).to eq(200)

        expect(CGI.unescapeHTML(response.body))
          .to include(I18n.t('password_reset.no_token'))

        expect(response.body).to_not have_tag(:script, with: {
          src: '/assets/application.js'
        })

        expect(session[:current_user_id]).to be_blank
      end

      it "responds with proper error message" do
        put "/u/password-reset/evil_trout!.json", params: { password: "awesomeSecretPassword" }

        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)["message"]).to eq(I18n.t('password_reset.no_token'))
        expect(session[:current_user_id]).to be_blank
      end
    end

    context 'valid token' do
      context 'when rendered' do
        it 'renders referrer never on get requests' do
          user = Fabricate(:user)
          token = user.email_tokens.create(email: user.email).token
          get "/u/password-reset/#{token}"
          expect(response.status).to eq(200)
          expect(response.body).to include('<meta name="referrer" content="never">')
        end
      end

      it 'returns success' do
        user = Fabricate(:user)
        user_auth_token = UserAuthToken.generate!(user_id: user.id)
        token = user.email_tokens.create(email: user.email).token

        events = DiscourseEvent.track_events do
          put "/u/password-reset/#{token}", params: { password: 'hg9ow8yhg98o' }
        end

        expect(events.map { |event| event[:event_name] }).to contain_exactly(
          :user_logged_in, :user_first_logged_in
        )

        expect(response.status).to eq(200)
        expect(response.body).to have_tag("div#data-preloaded") do |element|
          json = JSON.parse(element.current_scope.attribute('data-preloaded').value)
          expect(json['password_reset']).to include('{"is_developer":false,"admin":false,"second_factor_required":false,"security_key_required":false,"backup_enabled":false}')
        end

        expect(session["password-#{token}"]).to be_blank
        expect(UserAuthToken.where(id: user_auth_token.id).count).to eq(0)
      end

      it 'disallows double password reset' do
        user = Fabricate(:user)
        token = user.email_tokens.create(email: user.email).token

        put "/u/password-reset/#{token}", params: { password: 'hg9ow8yHG32O' }

        put "/u/password-reset/#{token}", params: { password: 'test123987AsdfXYZ' }

        user.reload
        expect(user.confirm_password?('hg9ow8yHG32O')).to eq(true)

        # logged in now
        expect(user.user_auth_tokens.count).to eq(1)
      end

      it "doesn't redirect to wizard on get" do
        user = Fabricate(:admin)
        UserAuthToken.generate!(user_id: user.id)

        token = user.email_tokens.create(email: user.email).token
        get "/u/password-reset/#{token}.json"
        expect(response).not_to redirect_to(wizard_path)
      end

      it "redirects to the wizard if you're the first admin" do
        user = Fabricate(:admin)
        UserAuthToken.generate!(user_id: user.id)

        token = user.email_tokens.create(email: user.email).token
        get "/u/password-reset/#{token}"

        put "/u/password-reset/#{token}", params: { password: 'hg9ow8yhg98oadminlonger' }

        expect(response).to redirect_to(wizard_path)
      end

      it "logs the password change" do
        user = Fabricate(:admin)
        UserAuthToken.generate!(user_id: user.id)
        token = user.email_tokens.create(email: user.email).token
        get "/u/password-reset/#{token}"

        expect do
          put "/u/password-reset/#{token}", params: { password: 'hg9ow8yhg98oadminlonger' }
        end.to change { UserHistory.count }.by (1)

        entry = UserHistory.last

        expect(entry.target_user_id).to eq(user.id)
        expect(entry.action).to eq(UserHistory.actions[:change_password])
      end

      it "doesn't invalidate the token when loading the page" do
        user = Fabricate(:user)
        user_token = UserAuthToken.generate!(user_id: user.id)

        email_token = user.email_tokens.create(email: user.email)

        get "/u/password-reset/#{email_token.token}.json"
        expect(response.status).to eq(200)

        email_token.reload

        expect(email_token.confirmed).to eq(false)
        expect(UserAuthToken.where(id: user_token.id).count).to eq(1)
      end

      context "rate limiting" do

        before { RateLimiter.clear_all!; RateLimiter.enable }
        after  { RateLimiter.disable }

        it "rate limits reset passwords" do
          freeze_time

          token = user.email_tokens.create!(email: user.email).token

          3.times do
            put "/u/password-reset/#{token}", params: {
              second_factor_token: 123456,
              second_factor_method: 1
            }

            expect(response.status).to eq(200)
          end

          put "/u/password-reset/#{token}", params: {
            second_factor_token: 123456,
            second_factor_method: 1
          }

          expect(response.status).to eq(429)
        end

      end

      context '2 factor authentication required' do
        let!(:second_factor) { Fabricate(:user_second_factor_totp, user: user) }

        it 'does not change with an invalid token' do
          token = user.email_tokens.create!(email: user.email).token

          get "/u/password-reset/#{token}"

          expect(response.body).to have_tag("div#data-preloaded") do |element|
            json = JSON.parse(element.current_scope.attribute('data-preloaded').value)
            expect(json['password_reset']).to include('{"is_developer":false,"admin":false,"second_factor_required":true,"security_key_required":false,"backup_enabled":false}')
          end

          put "/u/password-reset/#{token}", params: {
            password: 'hg9ow8yHG32O',
            second_factor_token: '000000',
            second_factor_method: UserSecondFactor.methods[:totp]
          }

          expect(response.body).to include(I18n.t("login.invalid_second_factor_code"))

          user.reload
          expect(user.confirm_password?('hg9ow8yHG32O')).not_to eq(true)
          expect(user.user_auth_tokens.count).not_to eq(1)
        end

        it 'changes password with valid 2-factor tokens' do
          token = user.email_tokens.create(email: user.email).token

          get "/u/password-reset/#{token}"

          put "/u/password-reset/#{token}", params: {
            password: 'hg9ow8yHG32O',
            second_factor_token: ROTP::TOTP.new(second_factor.data).now,
            second_factor_method: UserSecondFactor.methods[:totp]
          }

          user.reload
          expect(response.status).to eq(200)
          expect(user.confirm_password?('hg9ow8yHG32O')).to eq(true)
          expect(user.user_auth_tokens.count).to eq(1)
        end
      end

      context 'security key authentication required' do
        let!(:security_key) { Fabricate(:user_security_key, user: user, factor_type: UserSecurityKey.factor_types[:second_factor]) }

        it 'preloads with a security key challenge and allowed credential ids' do
          token = user.email_tokens.create!(email: user.email).token

          get "/u/password-reset/#{token}"

          expect(response.body).to have_tag("div#data-preloaded") do |element|
            json = JSON.parse(element.current_scope.attribute('data-preloaded').value)
            password_reset = JSON.parse(json['password_reset'])
            expect(password_reset['challenge']).not_to eq(nil)
            expect(password_reset['allowed_credential_ids']).to eq([security_key.credential_id])
            expect(password_reset['security_key_required']).to eq(true)
          end
        end

        it 'stages a webauthn challenge and rp-id for the user' do
          token = user.email_tokens.create!(email: user.email).token

          get "/u/password-reset/#{token}"

          secure_session = SecureSession.new(session["secure_session_id"])
          expect(secure_session["staged-webauthn-challenge-#{user.id}"]).not_to eq(nil)
          expect(secure_session["staged-webauthn-rp-id-#{user.id}"]).to eq(Discourse.current_hostname)
        end

        it 'changes password with valid security key challenge and authentication' do
          token = user.email_tokens.create(email: user.email).token

          get "/u/password-reset/#{token}"

          ::Webauthn::SecurityKeyAuthenticationService.any_instance.stubs(:authenticate_security_key).returns(true)

          put "/u/password-reset/#{token}", params: {
            password: 'hg9ow8yHG32O',
            security_key_credential: {
              signature: 'test',
              clientData: 'test',
              authenticatorData: 'test',
              credentialId: 'test'
            },
            second_factor_method: UserSecondFactor.methods[:security_key]
          }

          user.reload
          expect(response.status).to eq(200)
          expect(user.confirm_password?('hg9ow8yHG32O')).to eq(true)
          expect(user.user_auth_tokens.count).to eq(1)
        end
      end
    end

    context 'submit change' do
      let(:token) { EmailToken.generate_token }

      before do
        EmailToken.expects(:confirm).with(token).returns(user)
      end

      it "fails when the password is blank" do
        put "/u/password-reset/#{token}.json", params: { password: '' }

        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)["errors"]).to be_present
        expect(session[:current_user_id]).to be_blank
      end

      it "fails when the password is too long" do
        put "/u/password-reset/#{token}.json", params: { password: ('x' * (User.max_password_length + 1)) }

        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)["errors"]).to be_present
        expect(session[:current_user_id]).to be_blank
      end

      it "logs in the user" do
        put "/u/password-reset/#{token}.json", params: { password: 'ksjafh928r' }

        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)["errors"]).to be_blank
        expect(session[:current_user_id]).to be_present
      end

      it "doesn't log in the user when not approved" do
        SiteSetting.must_approve_users = true

        put "/u/password-reset/#{token}.json", params: { password: 'ksjafh928r' }
        expect(JSON.parse(response.body)["errors"]).to be_blank
        expect(session[:current_user_id]).to be_blank
      end
    end
  end

  describe '#confirm_email_token' do
    fab!(:user) { Fabricate(:user) }

    it "token doesn't match any records" do
      email_token = user.email_tokens.create(email: user.email)
      get "/u/confirm-email-token/#{SecureRandom.hex}.json"
      expect(response.status).to eq(200)
      expect(email_token.reload.confirmed).to eq(false)
    end

    it "token matches" do
      email_token = user.email_tokens.create(email: user.email)
      get "/u/confirm-email-token/#{email_token.token}.json"
      expect(response.status).to eq(200)
      expect(email_token.reload.confirmed).to eq(true)
    end
  end

  describe '#admin_login' do
    fab!(:admin) { Fabricate(:admin) }
    fab!(:user) { Fabricate(:user) }

    context 'enqueues mail' do
      it 'enqueues mail with admin email and sso enabled' do
        put "/u/admin-login", params: { email: admin.email }
        expect(response.status).to eq(200)
        expect(Jobs::CriticalUserEmail.jobs.size).to eq(1)
        args = Jobs::CriticalUserEmail.jobs.first["args"].first
        expect(args["user_id"]).to eq(admin.id)
      end
    end

    context 'when email is incorrect' do
      it 'should return the right response' do
        put "/u/admin-login", params: { email: 'random' }

        expect(response.status).to eq(200)

        response_body = response.body

        expect(response_body).to match(I18n.t("admin_login.errors.unknown_email_address"))
        expect(response_body).to_not match(I18n.t("login.second_factor_description"))
      end
    end

    context 'logs in admin' do
      it 'does not log in admin with invalid token' do
        SiteSetting.sso_url = "https://www.example.com/sso"
        SiteSetting.enable_sso = true
        get "/u/admin-login/invalid"
        expect(session[:current_user_id]).to be_blank
      end

      context 'valid token' do
        it 'does log in admin with SSO disabled' do
          SiteSetting.enable_sso = false
          token = admin.email_tokens.create(email: admin.email).token

          get "/u/admin-login/#{token}"
          expect(response).to redirect_to('/')
          expect(session[:current_user_id]).to eq(admin.id)
        end

        it 'logs in admin with SSO enabled' do
          SiteSetting.sso_url = "https://www.example.com/sso"
          SiteSetting.enable_sso = true
          token = admin.email_tokens.create(email: admin.email).token

          get "/u/admin-login/#{token}"
          expect(response).to redirect_to('/')
          expect(session[:current_user_id]).to eq(admin.id)
        end
      end

      describe 'when 2 factor authentication is enabled' do
        fab!(:second_factor) { Fabricate(:user_second_factor_totp, user: admin) }
        fab!(:email_token) { Fabricate(:email_token, user: admin) }

        it 'does not log in when token required' do
          second_factor
          get "/u/admin-login/#{email_token.token}"
          expect(response).not_to redirect_to('/')
          expect(session[:current_user_id]).not_to eq(admin.id)
          expect(response.body).to include(I18n.t('login.second_factor_description'))
        end

        describe 'invalid 2 factor token' do
          it 'should display the right error' do
            second_factor

            put "/u/admin-login/#{email_token.token}", params: {
              second_factor_token: '13213',
              second_factor_method: UserSecondFactor.methods[:totp]
            }

            expect(response.status).to eq(200)
            expect(response.body).to include(I18n.t('login.second_factor_description'))
            expect(response.body).to include(I18n.t('login.invalid_second_factor_code'))
          end
        end

        it 'logs in when a valid 2-factor token is given' do
          put "/u/admin-login/#{email_token.token}", params: {
            second_factor_token: ROTP::TOTP.new(second_factor.data).now,
            second_factor_method: UserSecondFactor.methods[:totp]
          }

          expect(response).to redirect_to('/')
          expect(session[:current_user_id]).to eq(admin.id)
        end
      end

      describe 'when security key authentication required' do
        fab!(:security_key) { Fabricate(:user_security_key, user: admin) }
        fab!(:email_token) { Fabricate(:email_token, user: admin) }

        it 'does not log in when token required' do
          security_key
          get "/u/admin-login/#{email_token.token}"
          expect(response).not_to redirect_to('/')
          expect(session[:current_user_id]).not_to eq(admin.id)
          expect(response.body).to include(I18n.t('login.security_key_authenticate'))
        end

        describe 'invalid security key' do
          it 'should display the right error' do
            ::Webauthn::SecurityKeyAuthenticationService.any_instance.stubs(:authenticate_security_key).returns(false)

            put "/u/admin-login/#{email_token.token}", params: {
              security_key_credential: {
                signature: 'test',
                clientData: 'test',
                authenticatorData: 'test',
                credentialId: 'test'
              }.to_json,
              second_factor_method: UserSecondFactor.methods[:security_key]
            }

            expect(response.status).to eq(200)
            expect(response.body).to include(I18n.t('login.security_key_invalid'))
          end
        end

        it 'logs in when a valid security key is given' do
          ::Webauthn::SecurityKeyAuthenticationService.any_instance.stubs(:authenticate_security_key).returns(true)

          put "/u/admin-login/#{email_token.token}", params: {
            security_key_credential: {
              signature: 'test',
              clientData: 'test',
              authenticatorData: 'test',
              credentialId: 'test'
            }.to_json,
            second_factor_method: UserSecondFactor.methods[:security_key]
          }

          expect(response).to redirect_to('/')
          expect(session[:current_user_id]).to eq(admin.id)
        end
      end
    end
  end

  describe '#toggle_anon' do
    it 'allows you to toggle anon if enabled' do
      SiteSetting.allow_anonymous_posting = true

      user = sign_in(Fabricate(:user))
      user.trust_level = 1
      user.save!

      post "/u/toggle-anon.json"
      expect(response.status).to eq(200)
      expect(session[:current_user_id]).to eq(AnonymousShadowCreator.get(user).id)

      post "/u/toggle-anon.json"
      expect(response.status).to eq(200)
      expect(session[:current_user_id]).to eq(user.id)
    end
  end

  describe '#create' do
    def honeypot_magic(params)
      get '/u/hp.json'
      json = JSON.parse(response.body)
      params[:password_confirmation] = json["value"]
      params[:challenge] = json["challenge"].reverse
      params
    end

    before do
      UsersController.any_instance.stubs(:honeypot_value).returns(nil)
      UsersController.any_instance.stubs(:challenge_value).returns(nil)
      SiteSetting.allow_new_registrations = true
      @user = Fabricate.build(:user, password: "strongpassword")
    end

    let(:post_user_params) do
      { name: @user.name,
        username: @user.username,
        password: "strongpassword",
        email: @user.email }
    end

    def post_user
      post "/u.json", params: post_user_params
    end

    context 'when email params is missing' do
      it 'should raise the right error' do
        post "/u.json", params: {
          name: @user.name,
          username: @user.username,
          password: 'tesing12352343'
        }
        expect(response.status).to eq(400)
      end
    end

    context 'when creating a user' do
      it 'sets the user locale to I18n.locale' do
        SiteSetting.default_locale = 'en'
        I18n.stubs(:locale).returns(:fr)
        post_user
        expect(User.find_by(username: @user.username).locale).to eq('fr')
      end
    end

    context 'when creating a non active user (unconfirmed email)' do
      it 'returns 403 forbidden when local logins are disabled' do
        SiteSetting.enable_local_logins = false
        post_user

        expect(response.status).to eq(403)
      end

      it 'returns an error when new registrations are disabled' do
        SiteSetting.allow_new_registrations = false

        post_user
        expect(response.status).to eq(200)

        json = JSON.parse(response.body)
        expect(json['success']).to eq(false)
        expect(json['message']).to be_present
      end

      it 'creates a user correctly' do
        post_user
        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)['active']).to be_falsey

        # should save user_created_message in session
        expect(session["user_created_message"]).to be_present
        expect(session[SessionController::ACTIVATE_USER_KEY]).to be_present

        expect(Jobs::SendSystemMessage.jobs.size).to eq(0)

        expect(Jobs::CriticalUserEmail.jobs.size).to eq(1)
        args = Jobs::CriticalUserEmail.jobs.first["args"].first
        expect(args["type"]).to eq("signup")
      end

      context "`must approve users` site setting is enabled" do
        before { SiteSetting.must_approve_users = true }

        it 'creates a user correctly' do
          post_user
          expect(response.status).to eq(200)

          expect(JSON.parse(response.body)['active']).to be_falsey

          # should save user_created_message in session
          expect(session["user_created_message"]).to be_present
          expect(session[SessionController::ACTIVATE_USER_KEY]).to be_present

          expect(Jobs::SendSystemMessage.jobs.size).to eq(0)

          expect(Jobs::CriticalUserEmail.jobs.size).to eq(1)
          args = Jobs::CriticalUserEmail.jobs.first["args"].first
          expect(args["type"]).to eq("signup")
        end
      end

      context 'users already exists with given email' do
        let!(:existing) { Fabricate(:user, email: post_user_params[:email]) }

        it 'returns an error if hide_email_address_taken is disabled' do
          SiteSetting.hide_email_address_taken = false

          post_user
          expect(response.status).to eq(200)

          json = JSON.parse(response.body)
          expect(json['success']).to eq(false)
          expect(json['message']).to be_present
        end

        it 'returns success if hide_email_address_taken is enabled' do
          SiteSetting.hide_email_address_taken = true
          expect {
            post_user
          }.to_not change { User.count }

          expect(response.status).to eq(200)
          expect(session["user_created_message"]).to be_present

          json = JSON.parse(response.body)
          expect(json['active']).to be_falsey
          expect(json['message']).to eq(I18n.t("login.activate_email", email: post_user_params[:email]))
        end
      end
    end

    context "creating as active" do
      it "won't create the user as active" do
        post "/u.json", params: post_user_params.merge(active: true)
        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)['active']).to be_falsey
      end

      context "with a regular api key" do
        fab!(:user) { Fabricate(:user) }
        fab!(:api_key) { Fabricate(:api_key, user: user) }

        it "won't create the user as active with a regular key" do
          post "/u.json",
            params: post_user_params.merge(active: true, api_key: api_key.key)

          expect(response.status).to eq(200)
          expect(JSON.parse(response.body)['active']).to be_falsey
        end
      end

      context "with an admin api key" do
        fab!(:admin) { Fabricate(:admin) }
        fab!(:api_key) { Fabricate(:api_key, user: admin) }

        it "creates the user as active with a an admin key" do
          SiteSetting.send_welcome_message = true
          SiteSetting.must_approve_users = true

          #Sidekiq::Client.expects(:enqueue).never
          post "/u.json", params: post_user_params.merge(approved: true, active: true, api_key: api_key.key)

          expect(Jobs::CriticalUserEmail.jobs.size).to eq(0)
          expect(Jobs::SendSystemMessage.jobs.size).to eq(0)

          expect(response.status).to eq(200)
          json = JSON.parse(response.body)

          new_user = User.find(json["user_id"])

          expect(json['active']).to be_truthy

          expect(new_user.active).to eq(true)
          expect(new_user.approved).to eq(true)
          expect(new_user.approved_by_id).to eq(admin.id)
          expect(new_user.approved_at).to_not eq(nil)
        end

        it "will create a reviewable when a user is created as active but not approved" do
          Jobs.run_immediately!
          SiteSetting.must_approve_users = true

          post "/u.json", params: post_user_params.merge(active: true, api_key: api_key.key)

          expect(response.status).to eq(200)
          json = JSON.parse(response.body)

          new_user = User.find(json["user_id"])
          expect(json['active']).to be_truthy
          expect(new_user.approved).to eq(false)
          expect(ReviewableUser.pending.find_by(target: new_user)).to be_present
        end

        it "won't create a reviewable when a user is not active" do
          Jobs.run_immediately!
          SiteSetting.must_approve_users = true

          post "/u.json", params: post_user_params.merge(api_key: api_key.key)

          expect(response.status).to eq(200)
          json = JSON.parse(response.body)

          new_user = User.find(json["user_id"])
          expect(json['active']).to eq(false)
          expect(new_user.approved).to eq(false)
          expect(ReviewableUser.pending.find_by(target: new_user)).to be_blank
        end

        it "won't create the developer as active" do
          UsernameCheckerService.expects(:is_developer?).returns(true)

          post "/u.json", params: post_user_params.merge(active: true, api_key: api_key.key)
          expect(response.status).to eq(200)
          expect(JSON.parse(response.body)['active']).to be_falsy
        end

        it "won't set the new user's locale to the admin's locale" do
          SiteSetting.allow_user_locale = true
          admin.update!(locale: :fr)

          post "/u.json", params: post_user_params.merge(active: true, api_key: api_key.key)
          expect(response.status).to eq(200)

          json = JSON.parse(response.body)
          new_user = User.find(json["user_id"])
          expect(new_user.locale).not_to eq("fr")
        end
      end
    end

    context "creating as staged" do
      it "won't create the user as staged" do
        post "/u.json", params: post_user_params.merge(staged: true)
        expect(response.status).to eq(200)
        new_user = User.where(username: post_user_params[:username]).first
        expect(new_user.staged?).to eq(false)
      end

      context "with a regular api key" do
        fab!(:user) { Fabricate(:user) }
        fab!(:api_key) { Fabricate(:api_key, user: user) }

        it "won't create the user as staged with a regular key" do
          post "/u.json", params: post_user_params.merge(staged: true, api_key: api_key.key)
          expect(response.status).to eq(200)

          new_user = User.where(username: post_user_params[:username]).first
          expect(new_user.staged?).to eq(false)
        end
      end

      context "with an admin api key" do
        fab!(:user) { Fabricate(:admin) }
        fab!(:api_key) { Fabricate(:api_key, user: user) }

        it "creates the user as staged with a regular key" do
          post "/u.json", params: post_user_params.merge(staged: true, api_key: api_key.key)
          expect(response.status).to eq(200)

          new_user = User.where(username: post_user_params[:username]).first
          expect(new_user.staged?).to eq(true)
        end

        it "won't create the developer as staged" do
          UsernameCheckerService.expects(:is_developer?).returns(true)
          post "/u.json", params: post_user_params.merge(staged: true, api_key: api_key.key)
          expect(response.status).to eq(200)

          new_user = User.where(username: post_user_params[:username]).first
          expect(new_user.staged?).to eq(false)
        end
      end
    end

    context 'when creating an active user (confirmed email)' do
      before { User.any_instance.stubs(:active?).returns(true) }

      it 'enqueues a welcome email' do
        User.any_instance.expects(:enqueue_welcome_message).with('welcome_user')

        post_user
        expect(response.status).to eq(200)

        # should save user_created_message in session
        expect(session["user_created_message"]).to be_present
        expect(session[SessionController::ACTIVATE_USER_KEY]).to be_present
      end

      it "shows the 'active' message" do
        User.any_instance.expects(:enqueue_welcome_message)
        post_user
        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)['message']).to eq(
          I18n.t 'login.active'
        )
      end

      it "should be logged in" do
        User.any_instance.expects(:enqueue_welcome_message)
        post_user
        expect(response.status).to eq(200)
        expect(session[:current_user_id]).to be_present
      end

      it 'indicates the user is active in the response' do
        User.any_instance.expects(:enqueue_welcome_message)
        post_user
        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)['active']).to be_truthy
      end

      it 'doesn\'t succeed when new registrations are disabled' do
        SiteSetting.allow_new_registrations = false

        post_user
        expect(response.status).to eq(200)

        json = JSON.parse(response.body)
        expect(json['success']).to eq(false)
        expect(json['message']).to be_present
      end

      context 'authentication records for' do
        before do
          OmniAuth.config.test_mode = true

          OmniAuth.config.mock_auth[:twitter] = OmniAuth::AuthHash.new(
            provider: 'twitter',
            uid: '123545',
            info: OmniAuth::AuthHash::InfoHash.new(
              email: "osama@mail.com",
              nickname: "testosama"
            )
          )

          Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:twitter]
          SiteSetting.enable_twitter_logins = true
          get "/auth/twitter/callback.json"
        end

        after do
          Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:twitter] = nil
          OmniAuth.config.test_mode = false
        end

        it 'should create twitter user info if required' do
          post "/u.json", params: {
            name: "Test Osama",
            username: "testosama",
            password: "strongpassword",
            email: "osama@mail.com"
          }

          expect(response.status).to eq(200)
          expect(UserAssociatedAccount.where(provider_name: "twitter").count).to eq(1)
        end

        it "returns an error when email has been changed from the validated email address" do
          post "/u.json", params: {
            name: "Test Osama",
            username: "testosama",
            password: "strongpassword",
            email: "unvalidatedemail@mail.com"
          }

          expect(response.status).to eq(200)
          json = JSON.parse(response.body)
          expect(json['success']).to eq(false)
          expect(json['message']).to be_present
        end

        it "will create the user successfully if email validation is required" do
          post "/u.json", params: {
            name: "Test Osama",
            username: "testosama",
            password: "strongpassword",
            email: "osama@mail.com"
          }

          expect(response.status).to eq(200)
          json = JSON.parse(response.body)
          expect(json['success']).to eq(true)
        end
      end
    end

    it "creates user successfully but doesn't activate the account" do
      post_user
      expect(response.status).to eq(200)
      json = JSON::parse(response.body)
      expect(json["success"]).to eq(true)
      expect(User.find_by(username: @user.username).active).to eq(false)
    end

    shared_examples 'honeypot fails' do
      it 'should not create a new user' do
        User.any_instance.expects(:enqueue_welcome_message).never

        expect {
          post "/u.json", params: create_params
        }.to_not change { User.count }

        expect(response.status).to eq(200)

        json = JSON::parse(response.body)
        expect(json["success"]).to eq(true)

        # should not change the session
        expect(session["user_created_message"]).to be_blank
        expect(session[SessionController::ACTIVATE_USER_KEY]).to be_blank
      end
    end

    context 'when honeypot value is wrong' do
      before do
        UsersController.any_instance.stubs(:honeypot_value).returns('abc')
      end
      let(:create_params) { { name: @user.name, username: @user.username, password: "strongpassword", email: @user.email, password_confirmation: 'wrong' } }
      include_examples 'honeypot fails'
    end

    context 'when challenge answer is wrong' do
      before do
        UsersController.any_instance.stubs(:challenge_value).returns('abc')
      end
      let(:create_params) { { name: @user.name, username: @user.username, password: "strongpassword", email: @user.email, challenge: 'abc' } }
      include_examples 'honeypot fails'
    end

    context "when 'invite only' setting is enabled" do
      before { SiteSetting.invite_only = true }

      let(:create_params) { {
        name: @user.name,
        username: @user.username,
        password: 'strongpassword',
        email: @user.email
      }}

      include_examples 'honeypot fails'
    end

    shared_examples 'failed signup' do
      it 'should not create a new User' do
        expect { post "/u.json", params: create_params }.to_not change { User.count }
        expect(response.status).to eq(200)
      end

      it 'should report failed' do
        post "/u.json", params: create_params
        json = JSON::parse(response.body)
        expect(json["success"]).not_to eq(true)

        # should not change the session
        expect(session["user_created_message"]).to be_blank
        expect(session[SessionController::ACTIVATE_USER_KEY]).to be_blank
      end
    end

    context 'when password is blank' do
      let(:create_params) { { name: @user.name, username: @user.username, password: "", email: @user.email } }
      include_examples 'failed signup'
    end

    context 'when password is too long' do
      let(:create_params) { { name: @user.name, username: @user.username, password: "x" * (User.max_password_length + 1), email: @user.email } }
      include_examples 'failed signup'
    end

    context 'when password param is missing' do
      let(:create_params) { { name: @user.name, username: @user.username, email: @user.email } }
      include_examples 'failed signup'
    end

    context 'with a reserved username' do
      let(:create_params) { { name: @user.name, username: 'Reserved', email: @user.email, password: 'strongpassword' } }
      before { SiteSetting.reserved_usernames = 'a|reserved|b' }
      include_examples 'failed signup'
    end

    context 'with a username that matches a user route' do
      let(:create_params) { { name: @user.name, username: 'account-created', email: @user.email, password: 'strongpassword' } }
      include_examples 'failed signup'
    end

    context 'with a missing username' do
      let(:create_params) { { name: @user.name, email: @user.email, password: "x" * 20 } }

      it 'should not create a new User' do
        expect { post "/u.json", params: create_params }.to_not change { User.count }
        expect(response.status).to eq(400)
      end
    end

    context 'when an Exception is raised' do
      before { User.any_instance.stubs(:save).raises(ActiveRecord::StatementInvalid.new('Oh no')) }

      let(:create_params) {
        { name: @user.name, username: @user.username,
          password: "strongpassword", email: @user.email }
      }

      include_examples 'failed signup'
    end

    context "with custom fields" do
      let!(:user_field) { Fabricate(:user_field) }
      let!(:another_field) { Fabricate(:user_field) }
      let!(:optional_field) { Fabricate(:user_field, required: false) }

      context "without a value for the fields" do
        let(:create_params) { { name: @user.name, password: 'watwatwat', username: @user.username, email: @user.email } }
        include_examples 'failed signup'
      end

      context "with values for the fields" do
        let(:create_params) { {
          name: @user.name,
          password: 'suChS3cuRi7y',
          username: @user.username,
          email: @user.email,
          user_fields: {
            user_field.id.to_s => 'value1',
            another_field.id.to_s => 'value2',
          }
        } }

        it "should succeed without the optional field" do
          post "/u.json", params: create_params
          expect(response.status).to eq(200)
          inserted = User.find_by_email(@user.email)
          expect(inserted).to be_present
          expect(inserted.custom_fields).to be_present
          expect(inserted.custom_fields["user_field_#{user_field.id}"]).to eq('value1')
          expect(inserted.custom_fields["user_field_#{another_field.id}"]).to eq('value2')
          expect(inserted.custom_fields["user_field_#{optional_field.id}"]).to be_blank
        end

        it "should succeed with the optional field" do
          create_params[:user_fields][optional_field.id.to_s] = 'value3'
          post "/u.json", params: create_params.merge(create_params)
          expect(response.status).to eq(200)
          inserted = User.find_by_email(@user.email)
          expect(inserted).to be_present
          expect(inserted.custom_fields).to be_present
          expect(inserted.custom_fields["user_field_#{user_field.id}"]).to eq('value1')
          expect(inserted.custom_fields["user_field_#{another_field.id}"]).to eq('value2')
          expect(inserted.custom_fields["user_field_#{optional_field.id}"]).to eq('value3')
        end

        it "trims excessively long fields" do
          create_params[:user_fields][optional_field.id.to_s] = ('x' * 3000)
          post "/u.json", params: create_params.merge(create_params)
          expect(response.status).to eq(200)
          inserted = User.find_by_email(@user.email)

          val = inserted.custom_fields["user_field_#{optional_field.id}"]
          expect(val.length).to eq(UserField.max_length)
        end
      end
    end

    context "with only optional custom fields" do
      let!(:user_field) { Fabricate(:user_field, required: false) }

      context "without values for the fields" do
        let(:create_params) { {
          name: @user.name,
          password: 'suChS3cuRi7y',
          username: @user.username,
          email: @user.email,
        } }

        it "should succeed" do
          post "/u.json", params: create_params
          expect(response.status).to eq(200)
          inserted = User.find_by_email(@user.email)
          expect(inserted).to be_present
          expect(inserted.custom_fields).not_to be_present
          expect(inserted.custom_fields["user_field_#{user_field.id}"]).to be_blank
        end
      end
    end

    context "when taking over a staged account" do
      before do
        UsersController.any_instance.stubs(:honeypot_value).returns("abc")
        UsersController.any_instance.stubs(:challenge_value).returns("efg")
      end

      let!(:staged) { Fabricate(:staged, email: "staged@account.com", active: true) }

      it "succeeds" do
        post '/u.json', params: honeypot_magic(
          email: staged.email,
          username: "zogstrip",
          password: "P4ssw0rd$$"
        )

        expect(response.status).to eq(200)
        result = ::JSON.parse(response.body)
        expect(result["success"]).to eq(true)

        created_user = User.find_by_email(staged.email)
        expect(created_user.staged).to eq(false)
        expect(created_user.active).to eq(false)
        expect(created_user.registration_ip_address).to be_present
        expect(!!created_user.custom_fields["from_staged"]).to eq(true)

        # do not allow emails changes please

        put "/u/update-activation-email.json", params: { email: 'bob@bob.com' }

        created_user.reload
        expect(created_user.email).to eq("staged@account.com")
        expect(response.status).to eq(403)
      end
    end
  end

  describe '#username' do
    it 'raises an error when not logged in' do
      put "/u/somename/preferences/username.json"
      expect(response.status).to eq(403)
    end

    context 'while logged in' do
      let(:old_username) { "OrigUsrname" }
      let(:new_username) { "#{old_username}1234" }
      let(:user) { Fabricate(:user, username: old_username) }

      before do
        user.username = old_username
        sign_in(user)
      end

      it 'raises an error without a new_username param' do
        put "/u/#{user.username}/preferences/username.json", params: { username: user.username }
        expect(response.status).to eq(400)
        expect(user.reload.username).to eq(old_username)
      end

      it 'raises an error when you don\'t have permission to change the username' do
        Guardian.any_instance.expects(:can_edit_username?).with(user).returns(false)

        put "/u/#{user.username}/preferences/username.json", params: { new_username: new_username }

        expect(response).to be_forbidden
        expect(user.reload.username).to eq(old_username)
      end

      it 'raises an error when change_username fails' do
        put "/u/#{user.username}/preferences/username.json", params: { new_username: '@' }

        expect(response.status).to eq(422)

        body = JSON.parse(response.body)

        expect(body['errors'].first).to include(I18n.t(
          'user.username.short', min: User.username_length.begin
        ))

        expect(user.reload.username).to eq(old_username)
      end

      it 'should succeed in normal circumstances' do
        put "/u/#{user.username}/preferences/username.json", params: { new_username: new_username }

        expect(response.status).to eq(200)
        expect(user.reload.username).to eq(new_username)
      end

      it 'raises an error when the username clashes with an existing user route' do
        put "/u/#{user.username}/preferences/username.json", params: { new_username: 'account-created' }

        body = JSON.parse(response.body)

        expect(body['errors'].first).to include(I18n.t('login.reserved_username'))
      end

      it 'raises an error when the username is in the reserved list' do
        SiteSetting.reserved_usernames = 'reserved'

        put "/u/#{user.username}/preferences/username.json", params: { new_username: 'reserved' }
        body = JSON.parse(response.body)

        expect(body['errors'].first).to include(I18n.t('login.reserved_username'))
      end

      it 'should fail if the user is old' do
        # Older than the change period and >1 post
        user.created_at = Time.now - (SiteSetting.username_change_period + 1).days
        PostCreator.new(user,
          title: 'This is a test topic',
          raw: 'This is a test this is a test'
        ).create

        put "/u/#{user.username}/preferences/username.json", params: { new_username: new_username }

        expect(response).to be_forbidden
        expect(user.reload.username).to eq(old_username)
      end

      it 'should create a staff action log when a staff member changes the username' do
        acting_user = Fabricate(:admin)
        sign_in(acting_user)

        put "/u/#{user.username}/preferences/username.json", params: { new_username: new_username }

        expect(response.status).to eq(200)
        expect(UserHistory.where(action: UserHistory.actions[:change_username], target_user_id: user.id, acting_user_id: acting_user.id)).to be_present
        expect(user.reload.username).to eq(new_username)
      end

      it 'should return a JSON response with the updated username' do
        put "/u/#{user.username}/preferences/username.json", params: { new_username: new_username }

        expect(::JSON.parse(response.body)['username']).to eq(new_username)
      end

      it 'should respond with proper error message if sso_overrides_username is enabled' do
        SiteSetting.sso_url = 'http://someurl.com'
        SiteSetting.enable_sso = true
        SiteSetting.sso_overrides_username = true
        acting_user = Fabricate(:admin)
        sign_in(acting_user)

        put "/u/#{user.username}/preferences/username.json", params: { new_username: new_username }

        expect(response.status).to eq(422)
        expect(::JSON.parse(response.body)['errors'].first).to include(I18n.t('errors.messages.sso_overrides_username'))
      end
    end
  end

  describe '#check_username' do
    it 'raises an error without any parameters' do
      get "/u/check_username.json"
      expect(response.status).to eq(400)
    end

    shared_examples 'when username is unavailable' do
      it 'should return available as false in the JSON and return a suggested username' do
        expect(response.status).to eq(200)
        expect(::JSON.parse(response.body)['available']).to eq(false)
        expect(::JSON.parse(response.body)['suggestion']).to be_present
      end
    end

    shared_examples 'when username is available' do
      it 'should return available in the JSON' do
        expect(response.status).to eq(200)
        expect(::JSON.parse(response.body)['available']).to eq(true)
      end
    end

    it 'returns nothing when given an email param but no username' do
      get "/u/check_username.json", params: { email: 'dood@example.com' }
      expect(response.status).to eq(200)
    end

    context 'username is available' do
      before do
        get "/u/check_username.json", params: { username: 'BruceWayne' }
      end
      include_examples 'when username is available'
    end

    context 'username is unavailable' do
      let!(:user) { Fabricate(:user) }
      before do
        get "/u/check_username.json", params: { username: user.username }
      end
      include_examples 'when username is unavailable'
    end

    shared_examples 'checking an invalid username' do
      it 'should not return an available key but should return an error message' do
        expect(response.status).to eq(200)
        expect(::JSON.parse(response.body)['available']).to eq(nil)
        expect(::JSON.parse(response.body)['errors']).to be_present
      end
    end

    context 'has invalid characters' do
      before do
        get "/u/check_username.json", params: { username: 'bad username' }
      end
      include_examples 'checking an invalid username'

      it 'should return the invalid characters message' do
        expect(response.status).to eq(200)
        expect(::JSON.parse(response.body)['errors']).to include(I18n.t(:'user.username.characters'))
      end
    end

    context 'is too long' do
      before do
        get "/u/check_username.json", params: { username: generate_username(User.username_length.last + 1) }
      end
      include_examples 'checking an invalid username'

      it 'should return the "too long" message' do
        expect(response.status).to eq(200)
        expect(::JSON.parse(response.body)['errors']).to include(I18n.t(:'user.username.long', max: User.username_length.end))
      end
    end

    describe 'different case of existing username' do
      context "it's my username" do
        let!(:user) { Fabricate(:user, username: 'hansolo') }
        before do
          sign_in(user)

          get "/u/check_username.json", params: { username: 'HanSolo' }
        end
        include_examples 'when username is available'
      end

      context "it's someone else's username" do
        let!(:user) { Fabricate(:user, username: 'hansolo') }
        before do
          sign_in(Fabricate(:user))

          get "/u/check_username.json", params: { username: 'HanSolo' }
        end
        include_examples 'when username is unavailable'
      end

      context "an admin changing it for someone else" do
        let!(:user) { Fabricate(:user, username: 'hansolo') }
        before do
          sign_in(Fabricate(:admin))

          get "/u/check_username.json", params: { username: 'HanSolo', for_user_id: user.id }
        end
        include_examples 'when username is available'
      end
    end
  end

  describe '#invited' do
    it 'returns success' do
      user = Fabricate(:user)
      get "/u/#{user.username}/invited.json", params: { username: user.username }

      expect(response.status).to eq(200)
    end

    it 'filters by email' do
      inviter = Fabricate(:user)
      invitee = Fabricate(:user)
      Fabricate(
        :invite,
        email: 'billybob@example.com',
        invited_by: inviter,
        user: invitee
      )
      Fabricate(
        :invite,
        email: 'jimtom@example.com',
        invited_by: inviter,
        user: invitee
      )

      get "/u/#{inviter.username}/invited.json", params: { search: 'billybob' }

      invites = JSON.parse(response.body)['invites']
      expect(invites.size).to eq(1)
      expect(invites.first).to include('email' => 'billybob@example.com')
    end

    it 'filters by username' do
      inviter = Fabricate(:user)
      invitee = Fabricate(:user, username: 'billybob')
      _invite = Fabricate(
        :invite,
        invited_by: inviter,
        email: 'billybob@example.com',
        user: invitee
      )
      Fabricate(
        :invite,
        invited_by: inviter,
        user: Fabricate(:user, username: 'jimtom')
      )

      get "/u/#{inviter.username}/invited.json", params: { search: 'billybob' }

      invites = JSON.parse(response.body)['invites']
      expect(invites.size).to eq(1)
      expect(invites.first).to include('email' => 'billybob@example.com')
    end

    context 'with guest' do
      context 'with pending invites' do
        it 'does not return invites' do
          inviter = Fabricate(:user)
          Fabricate(:invite, invited_by: inviter)

          get "/u/#{user.username}/invited/pending.json"

          invites = JSON.parse(response.body)['invites']
          expect(invites).to be_empty
        end
      end

      context 'with redeemed invites' do
        it 'returns invites' do
          inviter = Fabricate(:user)
          invitee = Fabricate(:user)
          invite = Fabricate(:invite, invited_by: inviter, user: invitee)

          get "/u/#{inviter.username}/invited.json"

          invites = JSON.parse(response.body)['invites']
          expect(invites.size).to eq(1)
          expect(invites.first).to include('email' => invite.email)
        end
      end
    end

    context 'with authenticated user' do
      context 'with pending invites' do
        context 'with permission to see pending invites' do
          it 'returns invites' do
            inviter = Fabricate(:user)
            invite = Fabricate(:invite, invited_by: inviter)
            sign_in(inviter)

            get "/u/#{inviter.username}/invited/pending.json"

            invites = JSON.parse(response.body)['invites']
            expect(invites.size).to eq(1)
            expect(invites.first).to include("email" => invite.email)
          end
        end

        context 'without permission to see pending invites' do
          it 'does not return invites' do
            user = sign_in(Fabricate(:user))
            inviter = Fabricate(:user)
            _invitee = Fabricate(:user)
            Fabricate(:invite, invited_by: inviter)
            stub_guardian(user) do |guardian|
              guardian.stubs(:can_see_invite_details?).
                with(inviter).returns(false)
            end

            get "/u/#{inviter.username}/invited/pending.json"

            json = JSON.parse(response.body)['invites']
            expect(json).to be_empty
          end
        end
      end

      context 'with redeemed invites' do
        it 'returns invites' do
          _user = sign_in(Fabricate(:user))
          inviter = Fabricate(:user)
          invitee = Fabricate(:user)
          invite = Fabricate(:invite, invited_by: inviter, user: invitee)

          get "/u/#{inviter.username}/invited.json"

          invites = JSON.parse(response.body)['invites']
          expect(invites.size).to eq(1)
          expect(invites.first).to include('email' => invite.email)
        end
      end
    end
  end

  describe '#update' do
    context 'with guest' do
      it 'raises an error' do
        put "/u/guest.json"
        expect(response.status).to eq(403)
      end
    end

    context "when username contains a period" do
      before do
        sign_in(user)
      end

      fab!(:user) { Fabricate(:user, username: 'test.test', name: "Test User") }

      it "should be able to update a user" do
        put "/u/#{user.username}", params: { name: 'test.test' }

        expect(response.status).to eq(200)
        expect(user.reload.name).to eq('test.test')
      end
    end

    context "as a staff user" do
      context "uneditable field" do
        let!(:user_field) { Fabricate(:user_field, editable: false) }

        it "allows staff to edit the field" do
          sign_in(Fabricate(:admin))
          user = Fabricate(:user)
          put "/u/#{user.username}.json", params: {
            name: 'Jim Tom',
            title: "foobar",
            user_fields: { user_field.id.to_s => 'happy' }
          }

          expect(response.status).to eq(200)

          user.reload

          expect(user.user_fields[user_field.id.to_s]).to eq('happy')
          expect(user.title).to eq("foobar")
        end
      end
    end

    context 'with authenticated user' do
      context 'with permission to update' do
        let(:upload) { Fabricate(:upload) }
        let!(:user) { sign_in(Fabricate(:user)) }

        it 'allows the update' do
          user2 = Fabricate(:user)
          user3 = Fabricate(:user)
          tags = [Fabricate(:tag), Fabricate(:tag)]

          put "/u/#{user.username}.json", params: {
            name: 'Jim Tom',
            muted_usernames: "#{user2.username},#{user3.username}",
            watched_tags: "#{tags[0].name},#{tags[1].name}",
            card_background_upload_url: upload.url,
            profile_background_upload_url: upload.url
          }

          expect(response.status).to eq(200)

          user.reload

          expect(user.name).to eq 'Jim Tom'
          expect(user.muted_users.pluck(:username).sort).to eq [user2.username, user3.username].sort

          expect(TagUser.where(
            user: user,
            notification_level: TagUser.notification_levels[:watching]
          ).pluck(:tag_id)).to contain_exactly(tags[0].id, tags[1].id)

          theme = Fabricate(:theme, user_selectable: true)

          put "/u/#{user.username}.json", params: {
            muted_usernames: "",
            theme_ids: [theme.id],
            email_level: UserOption.email_level_types[:always]
          }

          user.reload

          expect(user.muted_users.pluck(:username).sort).to be_empty
          expect(user.user_option.theme_ids).to eq([theme.id])
          expect(user.user_option.email_level).to eq(UserOption.email_level_types[:always])
          expect(user.profile_background_upload).to eq(upload)
          expect(user.card_background_upload).to eq(upload)
        end

        context 'a locale is chosen that differs from I18n.locale' do
          it "updates the user's locale" do
            I18n.stubs(:locale).returns('fr')
            put "/u/#{user.username}.json", params: { locale: :fa_IR }
            expect(User.find_by(username: user.username).locale).to eq('fa_IR')
          end
        end

        context "with user fields" do
          context "an editable field" do
            let!(:user_field) { Fabricate(:user_field) }
            let!(:optional_field) { Fabricate(:user_field, required: false) }

            it "should update the user field" do
              put "/u/#{user.username}.json", params: { name: 'Jim Tom', user_fields: { user_field.id.to_s => 'happy' } }

              expect(response.status).to eq(200)
              expect(user.user_fields[user_field.id.to_s]).to eq 'happy'
            end

            it "cannot be updated to blank" do
              put "/u/#{user.username}.json", params: { name: 'Jim Tom', user_fields: { user_field.id.to_s => '' } }

              expect(response.status).to eq(422)
              expect(user.user_fields[user_field.id.to_s]).not_to eq('happy')
            end

            it "trims excessively large fields" do
              put "/u/#{user.username}.json", params: { name: 'Jim Tom', user_fields: { user_field.id.to_s => ('x' * 3000) } }

              expect(user.user_fields[user_field.id.to_s].size).to eq(UserField.max_length)
            end

            it "should retain existing user fields" do
              put "/u/#{user.username}.json", params: { name: 'Jim Tom', user_fields: { user_field.id.to_s => 'happy', optional_field.id.to_s => 'feet' } }

              expect(response.status).to eq(200)
              expect(user.user_fields[user_field.id.to_s]).to eq('happy')
              expect(user.user_fields[optional_field.id.to_s]).to eq('feet')

              put "/u/#{user.username}.json", params: { name: 'Jim Tom', user_fields: { user_field.id.to_s => 'sad' } }

              expect(response.status).to eq(200)

              user.reload

              expect(user.user_fields[user_field.id.to_s]).to eq('sad')
              expect(user.user_fields[optional_field.id.to_s]).to eq('feet')
            end
          end

          context "uneditable field" do
            let!(:user_field) { Fabricate(:user_field, editable: false) }

            it "does not update the user field" do
              put "/u/#{user.username}.json", params: { name: 'Jim Tom', user_fields: { user_field.id.to_s => 'happy' } }

              expect(response.status).to eq(200)
              expect(user.user_fields[user_field.id.to_s]).to be_blank
            end
          end

          context "custom_field" do
            before do
              plugin = Plugin::Instance.new
              plugin.register_editable_user_custom_field :test2
              plugin.register_editable_user_custom_field :test3, staff_only: true
            end

            after do
              User.plugin_editable_user_custom_fields.clear
              User.plugin_staff_editable_user_custom_fields.clear
            end

            it "only updates allowed user fields" do
              put "/u/#{user.username}.json", params: { custom_fields: { test1: :hello1, test2: :hello2, test3: :hello3 } }

              expect(response.status).to eq(200)
              expect(user.custom_fields["test1"]).to be_blank
              expect(user.custom_fields["test2"]).to eq("hello2")
              expect(user.custom_fields["test3"]).to be_blank
            end

            it "works alongside a user field" do
              user_field = Fabricate(:user_field, editable: true)
              put "/u/#{user.username}.json", params: { custom_fields: { test1: :hello1, test2: :hello2, test3: :hello3 }, user_fields: { user_field.id.to_s => 'happy' } }
              expect(response.status).to eq(200)
              expect(user.custom_fields["test1"]).to be_blank
              expect(user.custom_fields["test2"]).to eq("hello2")
              expect(user.custom_fields["test3"]).to eq(nil)
              expect(user.user_fields[user_field.id.to_s]).to eq('happy')
            end

            it "works alongside a user field during creation" do
              api_key = Fabricate(:api_key, user: Fabricate(:admin))
              user_field = Fabricate(:user_field, editable: true)
              post "/u.json", params: {
                name: "Test User",
                username: "testuser",
                email: "user@mail.com",
                password: 'supersecure',
                active: true,
                custom_fields: {
                  test2: 'custom field value'
                },
                user_fields: {
                  user_field.id.to_s => 'user field value'
                },
                api_key: api_key.key
              }
              expect(response.status).to eq(200)
              u = User.find_by_email('user@mail.com')

              val = u.custom_fields["user_field_#{user_field.id}"]
              expect(val).to eq('user field value')

              val = u.custom_fields["test2"]
              expect(val).to eq('custom field value')
            end

            it "is secure when there are no registered editable fields" do
              User.plugin_editable_user_custom_fields.clear
              User.plugin_staff_editable_user_custom_fields.clear
              put "/u/#{user.username}.json", params: { custom_fields: { test1: :hello1, test2: :hello2, test3: :hello3 } }
              expect(response.status).to eq(200)
              expect(user.custom_fields["test1"]).to be_blank
              expect(user.custom_fields["test2"]).to be_blank
              expect(user.custom_fields["test3"]).to be_blank

              put "/u/#{user.username}.json", params: { custom_fields: ["arrayitem1", "arrayitem2"] }
              expect(response.status).to eq(200)
            end

            it "allows staff to edit staff-editable fields" do
              sign_in(Fabricate(:admin))
              put "/u/#{user.username}.json", params: { custom_fields: { test1: :hello1, test2: :hello2, test3: :hello3 } }

              expect(response.status).to eq(200)
              expect(user.custom_fields["test1"]).to be_blank
              expect(user.custom_fields["test2"]).to eq("hello2")
              expect(user.custom_fields["test3"]).to eq("hello3")
            end

          end
        end

        it 'returns user JSON' do
          put "/u/#{user.username}.json"

          json = JSON.parse(response.body)
          expect(json['user']['id']).to eq user.id
        end
      end

      context 'without permission to update' do
        it 'does not allow the update' do
          user = Fabricate(:user, name: 'Billy Bob')
          sign_in(Fabricate(:user))

          put "/u/#{user.username}.json", params: { name: 'Jim Tom' }

          expect(response).to be_forbidden
          expect(user.reload.name).not_to eq 'Jim Tom'
        end
      end
    end
  end

  describe '#badge_title' do
    fab!(:user) { Fabricate(:user) }
    fab!(:badge) { Fabricate(:badge) }
    let(:user_badge) { BadgeGranter.grant(badge, user) }

    it "sets the user's title to the badge name if it is titleable" do
      sign_in(user)

      put "/u/#{user.username}/preferences/badge_title.json", params: { user_badge_id: user_badge.id }

      expect(user.reload.title).not_to eq(badge.display_name)
      badge.update allow_title: true

      put "/u/#{user.username}/preferences/badge_title.json", params: { user_badge_id: user_badge.id }

      expect(user.reload.title).to eq(badge.display_name)
      expect(user.user_profile.badge_granted_title).to eq(true)

      user.title = "testing"
      user.save
      user.user_profile.reload
      expect(user.user_profile.badge_granted_title).to eq(false)
    end

    context "with overrided name" do
      fab!(:badge) { Fabricate(:badge, name: 'Demogorgon', allow_title: true) }
      let(:user_badge) { BadgeGranter.grant(badge, user) }

      before do
        TranslationOverride.upsert!('en', 'badges.demogorgon.name', 'Boss')
      end

      after do
        TranslationOverride.revert!('en', ['badges.demogorgon.name'])
      end

      it "uses the badge display name as user title" do
        sign_in(user)

        put "/u/#{user.username}/preferences/badge_title.json", params: { user_badge_id: user_badge.id }
        expect(user.reload.title).to eq(badge.display_name)
      end
    end
  end

  describe '#send_activation_email' do
    before do
      UsersController.any_instance.stubs(:honeypot_value).returns(nil)
      UsersController.any_instance.stubs(:challenge_value).returns(nil)
    end

    let(:post_user) do
      post "/u.json", params: {
        username: "osamatest",
        password: "strongpassword",
        email: "dsdsds@sasa.com"
      }

      User.find_by(username: "osamatest")
    end

    context 'for an existing user' do
      context 'for an activated account with email confirmed' do
        it 'fails' do
          user = post_user
          email_token = user.email_tokens.create(email: user.email).token
          EmailToken.confirm(email_token)

          post "/u/action/send_activation_email.json", params: { username: user.username }

          expect(response.status).to eq(409)
          expect(JSON.parse(response.body)['errors']).to include(I18n.t(
            'activation.activated'
          ))
          expect(session[SessionController::ACTIVATE_USER_KEY]).to eq(nil)
        end
      end

      context 'for an activated account with unconfirmed email' do
        it 'should send an email' do
          user = post_user
          user.update(active: true)
          user.save!
          user.email_tokens.create(email: user.email)
          Jobs.expects(:enqueue).with(:critical_user_email, has_entries(type: :signup, to_address: user.email))

          post "/u/action/send_activation_email.json", params: {
            username: user.username
          }

          expect(response.status).to eq(200)

          expect(session[SessionController::ACTIVATE_USER_KEY]).to eq(nil)
        end
      end

      context "approval is enabled" do
        before do
          SiteSetting.must_approve_users = true
        end

        it "should raise an error" do
          user = post_user
          user.update(active: true)
          user.save!
          user.email_tokens.create(email: user.email)
          post "/u/action/send_activation_email.json", params: {
            username: user.username
          }

          expect(response.status).to eq(403)
        end
      end

      describe 'when user does not have a valid session' do
        it 'should not be valid' do
          user = Fabricate(:user)
          post "/u/action/send_activation_email.json", params: {
            username: user.username
          }
          expect(response.status).to eq(403)
        end

        it 'should allow staff regardless' do
          sign_in(Fabricate(:admin))
          user = Fabricate(:user, active: false)
          post "/u/action/send_activation_email.json", params: {
            username: user.username
          }
          expect(response.status).to eq(200)
        end
      end

      context 'with a valid email_token' do
        it 'should send the activation email' do
          user = post_user
          Jobs.expects(:enqueue).with(:critical_user_email, has_entries(type: :signup))
          post "/u/action/send_activation_email.json", params: {
            username: user.username
          }
          expect(session[SessionController::ACTIVATE_USER_KEY]).to eq(nil)
        end
      end

      context 'without an existing email_token' do
        let(:user) { post_user }
        before do
          user.email_tokens.each { |t| t.destroy }
          user.reload
        end

        it 'should generate a new token' do
          expect {
            post "/u/action/send_activation_email.json", params: { username: user.username }
          }.to change { user.reload.email_tokens.count }.by(1)
        end

        it 'should send an email' do
          expect do
            post "/u/action/send_activation_email.json", params: {
              username: user.username
            }
          end.to change { Jobs::CriticalUserEmail.jobs.size }.by(1)

          expect(session[SessionController::ACTIVATE_USER_KEY]).to eq(nil)
        end
      end
    end

    context 'when username does not exist' do
      it 'should not send an email' do
        post "/u/action/send_activation_email.json", params: { username: 'nopenopenopenope' }
        expect(response.status).to eq(404)
        expect(Jobs::CriticalUserEmail.jobs.size).to eq(0)
      end
    end
  end

  describe '#pick_avatar' do
    it 'raises an error when not logged in' do
      put "/u/asdf/preferences/avatar/pick.json", params: { avatar_id: 1, type: "custom" }
      expect(response.status).to eq(403)
    end

    context 'while logged in' do
      before do
        sign_in(user)
      end

      let(:upload) do
        Fabricate(:upload, user: user)
      end

      it "raises an error when you don't have permission to toggle the avatar" do
        another_user = Fabricate(:user)
        put "/u/#{another_user.username}/preferences/avatar/pick.json", params: {
          upload_id: upload.id, type: "custom"
        }

        expect(response).to be_forbidden
      end

      it "raises an error when sso_overrides_avatar is disabled" do
        SiteSetting.sso_overrides_avatar = true
        put "/u/#{user.username}/preferences/avatar/pick.json", params: {
          upload_id: upload.id, type: "custom"
        }

        expect(response.status).to eq(422)
      end

      it "raises an error when selecting the custom/uploaded avatar and allow_uploaded_avatars is disabled" do
        SiteSetting.allow_uploaded_avatars = false
        put "/u/#{user.username}/preferences/avatar/pick.json", params: {
          upload_id: upload.id, type: "custom"
        }

        expect(response.status).to eq(422)
      end

      it 'can successfully pick the system avatar' do
        put "/u/#{user.username}/preferences/avatar/pick.json"

        expect(response.status).to eq(200)
        expect(user.reload.uploaded_avatar_id).to eq(nil)
      end

      it 'can successfully pick a gravatar' do

        user.user_avatar.update_columns(gravatar_upload_id: upload.id)

        put "/u/#{user.username}/preferences/avatar/pick.json", params: {
          upload_id: upload.id, type: "gravatar"
        }

        expect(response.status).to eq(200)
        expect(user.reload.uploaded_avatar_id).to eq(upload.id)
        expect(user.user_avatar.reload.gravatar_upload_id).to eq(upload.id)
      end

      it 'can not pick uploads that were not created by user' do
        upload2 = Fabricate(:upload)

        put "/u/#{user.username}/preferences/avatar/pick.json", params: {
          upload_id: upload2.id, type: "custom"
        }

        expect(response.status).to eq(403)
      end

      it 'can successfully pick a custom avatar' do
        events = DiscourseEvent.track_events do
          put "/u/#{user.username}/preferences/avatar/pick.json", params: {
            upload_id: upload.id, type: "custom"
          }
        end

        expect(events.map { |event| event[:event_name] }).to include(:user_updated)
        expect(response.status).to eq(200)
        expect(user.reload.uploaded_avatar_id).to eq(upload.id)
        expect(user.user_avatar.reload.custom_upload_id).to eq(upload.id)
      end
    end
  end

  describe '#select_avatar' do
    it 'raises an error when not logged in' do
      put "/u/asdf/preferences/avatar/select.json", params: { url: "https://meta.discourse.org" }
      expect(response.status).to eq(403)
    end

    context 'while logged in' do

      let!(:user) { sign_in(Fabricate(:user)) }
      fab!(:avatar1) { Fabricate(:upload) }
      fab!(:avatar2) { Fabricate(:upload) }
      let(:url) { "https://www.discourse.org" }

      it 'raises an error when url is blank' do
        put "/u/#{user.username}/preferences/avatar/select.json", params: { url: "" }
        expect(response.status).to eq(422)
      end

      it 'raises an error when selectable avatars is disabled' do
        put "/u/#{user.username}/preferences/avatar/select.json", params: { url: url }
        expect(response.status).to eq(422)
      end

      context 'selectable avatars is enabled' do

        before { SiteSetting.selectable_avatars_enabled = true }

        it 'raises an error when selectable avatars is empty' do
          put "/u/#{user.username}/preferences/avatar/select.json", params: { url: url }
          expect(response.status).to eq(422)
        end

        context 'selectable avatars is properly setup' do

          before do
            SiteSetting.selectable_avatars = [avatar1.url, avatar2.url].join("\n")
          end

          it 'raises an error when url is not in selectable avatars list' do
            put "/u/#{user.username}/preferences/avatar/select.json", params: { url: url }
            expect(response.status).to eq(422)
          end

          it 'can successfully select an avatar' do
            events = DiscourseEvent.track_events do
              put "/u/#{user.username}/preferences/avatar/select.json", params: { url: avatar1.url }
            end

            expect(events.map { |event| event[:event_name] }).to include(:user_updated)
            expect(response.status).to eq(200)
            expect(user.reload.uploaded_avatar_id).to eq(avatar1.id)
            expect(user.user_avatar.reload.custom_upload_id).to eq(avatar1.id)
          end
        end
      end
    end
  end

  describe '#destroy_user_image' do

    it 'raises an error when not logged in' do
      delete "/u/asdf/preferences/user_image.json", params: { type: 'profile_background' }
      expect(response.status).to eq(403)
    end

    context 'while logged in' do
      fab!(:another_user) { Fabricate(:user) }
      fab!(:user) { Fabricate(:user) }

      before do
        sign_in(user)
      end

      it 'raises an error when you don\'t have permission to clear the profile background' do
        delete "/u/#{another_user.username}/preferences/user_image.json", params: { type: 'profile_background' }
        expect(response).to be_forbidden
      end

      it "requires the `type` param" do
        delete "/u/#{user.username}/preferences/user_image.json"
        expect(response.status).to eq(400)
      end

      it "only allows certain `types`" do
        delete "/u/#{user.username}/preferences/user_image.json", params: { type: 'wat' }
        expect(response.status).to eq(400)
      end

      it 'can clear the profile background' do
        delete "/u/#{user.username}/preferences/user_image.json", params: { type: 'profile_background' }

        expect(user.reload.profile_background_upload).to eq(nil)
        expect(response.status).to eq(200)
      end
    end
  end

  describe '#destroy' do
    it 'raises an error when not logged in' do
      delete "/u/nobody.json"
      expect(response.status).to eq(403)
    end

    context 'while logged in' do
      fab!(:user) { Fabricate(:user) }
      fab!(:another_user) { Fabricate(:user) }
      before do
        sign_in(user)
      end

      it 'raises an error when you cannot delete your account' do
        UserDestroyer.any_instance.expects(:destroy).never
        stat = user.user_stat
        stat.post_count = 3
        stat.save!
        delete "/u/#{user.username}.json"
        expect(response).to be_forbidden
      end

      it "raises an error when you try to delete someone else's account" do
        UserDestroyer.any_instance.expects(:destroy).never
        delete "/u/#{another_user.username}.json"
        expect(response).to be_forbidden
      end

      it "deletes your account when you're allowed to" do
        UserDestroyer.any_instance.expects(:destroy).with(user, anything).returns(user)
        delete "/u/#{user.username}.json"
        expect(response.status).to eq(200)
      end
    end
  end

  describe '#ignore' do
    it 'raises an error when not logged in' do
      put "/u/#{user.username}/notification_level.json", params: { notification_level: "" }
      expect(response.status).to eq(403)
    end

    context 'while logged in' do
      fab!(:user) { Fabricate(:user, trust_level: 2) }
      fab!(:another_user) { Fabricate(:user) }
      before do
        sign_in(user)
      end

      let!(:ignored_user) { Fabricate(:ignored_user, user: user, ignored_user: another_user) }
      let!(:muted_user) { Fabricate(:muted_user, user: user, muted_user: another_user) }

      context 'when changing notification level to normal' do
        it 'changes notification level to normal' do
          put "/u/#{another_user.username}/notification_level.json", params: { notification_level: "normal" }
          expect(IgnoredUser.count).to eq(0)
          expect(MutedUser.count).to eq(0)
        end
      end

      context 'when changing notification level to mute' do
        it 'changes notification level to mute' do
          put "/u/#{another_user.username}/notification_level.json", params: { notification_level: "mute" }
          expect(IgnoredUser.count).to eq(0)
          expect(MutedUser.find_by(user_id: user.id, muted_user_id: another_user.id)).to be_present
        end
      end

      context 'when changing notification level to ignore' do
        it 'changes notification level to ignore' do
          put "/u/#{another_user.username}/notification_level.json", params: { notification_level: "ignore" }
          expect(MutedUser.count).to eq(0)
          expect(IgnoredUser.find_by(user_id: user.id, ignored_user_id: another_user.id)).to be_present
        end

        context 'when expiring_at param is set' do
          it 'changes notification level to ignore' do
            freeze_time(Time.now) do
              expiring_at = 3.days.from_now
              put "/u/#{another_user.username}/notification_level.json", params: { notification_level: "ignore", expiring_at: expiring_at }

              ignored_user = IgnoredUser.find_by(user_id: user.id, ignored_user_id: another_user.id)
              expect(ignored_user).to be_present
              expect(ignored_user.expiring_at.to_i).to eq(expiring_at.to_i)
              expect(MutedUser.count).to eq(0)
            end
          end
        end
      end
    end
  end

  describe "for user with period in username" do
    fab!(:user_with_period) { Fabricate(:user, username: "myname.test") }

    it "still works" do
      sign_in(user_with_period)
      UserDestroyer.any_instance.expects(:destroy).with(user_with_period, anything).returns(user_with_period)
      delete "/u/#{user_with_period.username}", xhr: true
      expect(response.status).to eq(200)
    end
  end

  describe '#my_redirect' do
    it "redirects if the user is not logged in" do
      get "/my/wat.json"
      expect(response).to be_redirect
    end

    context "when the user is logged in" do
      let!(:user) { sign_in(Fabricate(:user)) }

      it "will not redirect to an invalid path" do
        get "/my/wat/..password.txt"
        expect(response).not_to be_redirect
      end

      it "will redirect to an valid path" do
        get "/my/preferences.json"
        expect(response).to be_redirect
      end

      it "permits forward slashes" do
        get "/my/activity/posts.json"
        expect(response).to be_redirect
      end
    end
  end

  describe '#check_emails' do
    it 'raises an error when not logged in' do
      get "/u/zogstrip/emails.json"
      expect(response.status).to eq(403)
    end

    context 'while logged in' do
      let(:sign_in_admin) { sign_in(Fabricate(:admin)) }

      it "raises an error when you aren't allowed to check emails" do
        sign_in(Fabricate(:user))
        get "/u/#{Fabricate(:user).username}/emails.json"
        expect(response).to be_forbidden
      end

      it "returns emails and associated_accounts for self" do
        user = Fabricate(:user)
        sign_in(user)

        get "/u/#{user.username}/emails.json"

        expect(response.status).to eq(200)
        json = JSON.parse(response.body)
        expect(json["email"]).to eq(user.email)
        expect(json["secondary_emails"]).to eq(user.secondary_emails)
        expect(json["associated_accounts"]).to eq([])
      end

      it "returns emails and associated_accounts when you're allowed to see them" do
        user = Fabricate(:user)
        sign_in_admin

        get "/u/#{user.username}/emails.json"

        expect(response.status).to eq(200)
        json = JSON.parse(response.body)
        expect(json["email"]).to eq(user.email)
        expect(json["secondary_emails"]).to eq(user.secondary_emails)
        expect(json["associated_accounts"]).to eq([])
      end

      it "works on inactive users" do
        inactive_user = Fabricate(:user, active: false)
        sign_in_admin

        get "/u/#{inactive_user.username}/emails.json"

        expect(response.status).to eq(200)
        json = JSON.parse(response.body)
        expect(json["email"]).to eq(inactive_user.email)
        expect(json["secondary_emails"]).to eq(inactive_user.secondary_emails)
        expect(json["associated_accounts"]).to eq([])
      end
    end
  end

  describe '#is_local_username' do
    fab!(:user) { Fabricate(:user) }
    fab!(:group) { Fabricate(:group, name: "Discourse") }
    fab!(:topic) { Fabricate(:topic) }
    fab!(:allowed_user) { Fabricate(:user) }
    let(:private_topic) { Fabricate(:private_message_topic, user: allowed_user) }

    it "finds the user" do
      get "/u/is_local_username.json", params: { username: user.username }

      expect(response.status).to eq(200)
      json = JSON.parse(response.body)
      expect(json["valid"][0]).to eq(user.username)
    end

    it "finds the group" do
      get "/u/is_local_username.json", params: { username: group.name }

      expect(response.status).to eq(200)
      json = JSON.parse(response.body)
      expect(json["valid_groups"][0]).to eq(group.name)
    end

    it "supports multiples usernames" do
      get "/u/is_local_username.json", params: { usernames: [user.username, "system"] }

      expect(response.status).to eq(200)
      json = JSON.parse(response.body)
      expect(json["valid"].size).to eq(2)
    end

    it "never includes staged accounts" do
      staged = Fabricate(:user, staged: true)

      get "/u/is_local_username.json", params: { usernames: [staged.username] }

      expect(response.status).to eq(200)
      json = JSON.parse(response.body)
      expect(json["valid"].size).to eq(0)
    end

    it "returns user who cannot see topic" do
      Guardian.any_instance.expects(:can_see?).with(topic).returns(false)

      get "/u/is_local_username.json", params: {
        usernames: [user.username], topic_id: topic.id
      }

      expect(response.status).to eq(200)
      json = JSON.parse(response.body)
      expect(json["cannot_see"].size).to eq(1)
    end

    it "never returns a user who can see the topic" do
      Guardian.any_instance.expects(:can_see?).with(topic).returns(true)

      get "/u/is_local_username.json", params: {
        usernames: [user.username], topic_id: topic.id
      }

      expect(response.status).to eq(200)
      json = JSON.parse(response.body)
      expect(json["cannot_see"].size).to eq(0)
    end

    it "returns user who cannot see a private topic" do
      Guardian.any_instance.expects(:can_see?).with(private_topic).returns(false)

      get "/u/is_local_username.json", params: {
        usernames: [user.username], topic_id: private_topic.id
      }

      expect(response.status).to eq(200)
      json = JSON.parse(response.body)
      expect(json["cannot_see"].size).to eq(1)
    end

    it "never returns a user who can see the topic" do
      Guardian.any_instance.expects(:can_see?).with(private_topic).returns(true)

      get "/u/is_local_username.json", params: {
        usernames: [allowed_user.username], topic_id: private_topic.id
      }

      expect(response.status).to eq(200)
      json = JSON.parse(response.body)
      expect(json["cannot_see"].size).to eq(0)
    end
  end

  describe '#topic_tracking_state' do
    fab!(:user) { Fabricate(:user) }

    context 'anon' do
      it "raises an error on anon for topic_tracking_state" do
        get "/u/#{user.username}/topic-tracking-state.json"
        expect(response.status).to eq(403)
      end
    end

    context 'logged on' do
      it "detects new topic" do
        sign_in(user)

        topic = Fabricate(:topic)
        get "/u/#{user.username}/topic-tracking-state.json"

        expect(response.status).to eq(200)
        states = JSON.parse(response.body)
        expect(states[0]["topic_id"]).to eq(topic.id)
      end
    end
  end

  describe '#summary' do
    it "generates summary info" do
      user = Fabricate(:user)
      create_post(user: user)

      get "/u/#{user.username_lower}/summary.json"
      expect(response.status).to eq(200)
      json = JSON.parse(response.body)

      expect(json["user_summary"]["topic_count"]).to eq(1)
      expect(json["user_summary"]["post_count"]).to eq(0)
    end

    it "returns 404 for a hidden profile" do
      user = Fabricate(:user)
      user.user_option.update_column(:hide_profile_and_presence, true)

      get "/u/#{user.username_lower}/summary.json"
      expect(response.status).to eq(404)
    end
  end

  describe '#confirm_admin' do
    it "fails without a valid token" do
      get "/u/confirm-admin/invalid-token.json"
      expect(response).not_to be_successful
    end

    it "fails with a missing token" do
      get "/u/confirm-admin/a0a0a0a0a0.json"
      expect(response).to_not be_successful
    end

    it "succeeds with a valid code as anonymous" do
      user = Fabricate(:user)
      ac = AdminConfirmation.new(user, Fabricate(:admin))
      ac.create_confirmation
      get "/u/confirm-admin/#{ac.token}.json"
      expect(response.status).to eq(200)

      user.reload
      expect(user.admin?).to eq(false)
    end

    it "succeeds with a valid code when logged in as that user" do
      admin = sign_in(Fabricate(:admin))
      user = Fabricate(:user)

      ac = AdminConfirmation.new(user, admin)
      ac.create_confirmation
      get "/u/confirm-admin/#{ac.token}.json", params: { token: ac.token }
      expect(response.status).to eq(200)

      user.reload
      expect(user.admin?).to eq(false)
    end

    it "fails if you're logged in as a different account" do
      sign_in(Fabricate(:admin))
      user = Fabricate(:user)

      ac = AdminConfirmation.new(user, Fabricate(:admin))
      ac.create_confirmation
      get "/u/confirm-admin/#{ac.token}.json"
      expect(response).to_not be_successful

      user.reload
      expect(user.admin?).to eq(false)
    end

    describe "post" do
      it "gives the user admin access when POSTed" do
        user = Fabricate(:user)
        ac = AdminConfirmation.new(user, Fabricate(:admin))
        ac.create_confirmation
        post "/u/confirm-admin/#{ac.token}.json"
        expect(response.status).to eq(200)

        user.reload
        expect(user.admin?).to eq(true)
      end
    end
  end

  describe '#update_activation_email' do
    before do
      UsersController.any_instance.stubs(:honeypot_value).returns(nil)
      UsersController.any_instance.stubs(:challenge_value).returns(nil)
    end

    let(:post_user) do
      post "/u.json", params: {
        username: "osamatest",
        password: "strongpassword",
        email: "osama@example.com"
      }
      user = User.where(username: "osamatest").first
      user.active = false
      user.save!
      user
    end

    context "with a session variable" do
      it "raises an error with an invalid session value" do
        post_user

        post "/u.json", params: {
          username: "osamatest2",
          password: "strongpassword2",
          email: "osama22@example.com"
        }
        user = User.where(username: "osamatest2").first
        user.destroy

        put "/u/update-activation-email.json", params: {
          email: 'osamaupdated@example.com'
        }

        expect(response.status).to eq(403)
      end

      it "raises an error for an active user" do
        user = post_user
        user.update(active: true)
        user.save!

        put "/u/update-activation-email.json", params: {
          email: 'osama@example.com'
        }

        expect(response.status).to eq(403)
      end

      it "raises an error when logged in" do
        sign_in(Fabricate(:moderator))
        post_user

        put "/u/update-activation-email.json", params: {
          email: 'updatedemail@example.com'
        }

        expect(response.status).to eq(403)
      end

      it "raises an error when the new email is taken" do
        active_user = Fabricate(:user)
        post_user

        put "/u/update-activation-email.json", params: {
          email: active_user.email
        }

        expect(response.status).to eq(422)
      end

      it "raises an error when the email is blacklisted" do
        post_user
        SiteSetting.email_domains_blacklist = 'example.com'
        put "/u/update-activation-email.json", params: { email: 'test@example.com' }
        expect(response.status).to eq(422)
      end

      it "can be updated" do
        user = post_user
        token = user.email_tokens.first

        put "/u/update-activation-email.json", params: {
          email: 'updatedemail@example.com'
        }

        expect(response.status).to eq(200)

        user.reload
        expect(user.email).to eq('updatedemail@example.com')
        expect(user.email_tokens.where(email: 'updatedemail@example.com', expired: false)).to be_present

        token.reload
        expect(token.expired?).to eq(true)
      end
    end

    context "with a username and password" do
      it "raises an error with an invalid username" do
        put "/u/update-activation-email.json", params: {
          username: 'eviltrout',
          password: 'invalid-password',
          email: 'updatedemail@example.com'
        }

        expect(response.status).to eq(403)
      end

      it "raises an error with an invalid password" do
        put "/u/update-activation-email.json", params: {
          username: Fabricate(:inactive_user).username,
          password: 'invalid-password',
          email: 'updatedemail@example.com'
        }

        expect(response.status).to eq(403)
      end

      it "raises an error for an active user" do
        put "/u/update-activation-email.json", params: {
          username: Fabricate(:walter_white).username,
          password: 'letscook',
          email: 'updatedemail@example.com'
        }

        expect(response.status).to eq(403)
      end

      it "raises an error when logged in" do
        sign_in(Fabricate(:moderator))

        put "/u/update-activation-email.json", params: {
          username: Fabricate(:inactive_user).username,
          password: 'qwerqwer123',
          email: 'updatedemail@example.com'
        }

        expect(response.status).to eq(403)
      end

      it "raises an error when the new email is taken" do
        user = Fabricate(:user)

        put "/u/update-activation-email.json", params: {
          username: Fabricate(:inactive_user).username,
          password: 'qwerqwer123',
          email: user.email
        }

        expect(response.status).to eq(422)
      end

      it "can be updated" do
        user = Fabricate(:inactive_user)
        token = user.email_tokens.first

        put "/u/update-activation-email.json", params: {
          username: user.username,
          password: 'qwerqwer123',
          email: 'updatedemail@example.com'
        }

        expect(response.status).to eq(200)

        user.reload
        expect(user.email).to eq('updatedemail@example.com')
        expect(user.email_tokens.where(email: 'updatedemail@example.com', expired: false)).to be_present

        token.reload
        expect(token.expired?).to eq(true)
      end
    end
  end

  describe '#show' do
    context "anon" do
      let(:user) { Discourse.system_user }

      it "returns success" do
        get "/u/#{user.username}.json"
        expect(response.status).to eq(200)
        parsed = JSON.parse(response.body)["user"]

        expect(parsed['username']).to eq(user.username)
        expect(parsed["profile_hidden"]).to be_blank
        expect(parsed["trust_level"]).to be_present
      end

      it "returns a hidden profile" do
        user.user_option.update_column(:hide_profile_and_presence, true)

        get "/u/#{user.username}.json"
        expect(response.status).to eq(200)
        parsed = JSON.parse(response.body)["user"]

        expect(parsed["username"]).to eq(user.username)
        expect(parsed["profile_hidden"]).to eq(true)
        expect(parsed["trust_level"]).to be_blank
      end

      it "should redirect to login page for anonymous user when profiles are hidden" do
        SiteSetting.hide_user_profiles_from_public = true
        get "/u/#{user.username}.json"
        expect(response).to redirect_to '/login'
      end

      describe "user profile views" do
        fab!(:other_user) { Fabricate(:user) }

        it "should track a user profile view for an anon user" do
          get "/"
          UserProfileView.expects(:add).with(other_user.user_profile.id, request.remote_ip, nil)
          get "/u/#{other_user.username}.json"
        end

        it "skips tracking" do
          UserProfileView.expects(:add).never
          get "/u/#{user.username}.json", params: { skip_track_visit: true }
        end
      end
    end

    context "logged in" do
      before do
        sign_in(user)
      end

      fab!(:user) { Fabricate(:user) }

      it 'returns success' do
        get "/u/#{user.username}.json"
        expect(response.status).to eq(200)
        json = JSON.parse(response.body)

        expect(json["user"]["has_title_badges"]).to eq(false)
      end

      it "returns not found when the username doesn't exist" do
        get "/u/madeuppity.json"
        expect(response).not_to be_successful
      end

      it 'returns not found when the user is inactive' do
        inactive = Fabricate(:user, active: false)
        get "/u/#{inactive.username}.json"
        expect(response).not_to be_successful
      end

      it 'returns success when show_inactive_accounts is true and user is logged in' do
        SiteSetting.show_inactive_accounts = true
        inactive = Fabricate(:user, active: false)
        get "/u/#{inactive.username}.json"
        expect(response.status).to eq(200)
      end

      it "raises an error on invalid access" do
        Guardian.any_instance.expects(:can_see?).with(user).returns(false)
        get "/u/#{user.username}.json"
        expect(response).to be_forbidden
      end

      describe "user profile views" do
        fab!(:other_user) { Fabricate(:user) }

        it "should track a user profile view for a signed in user" do
          UserProfileView.expects(:add).with(other_user.user_profile.id, request.remote_ip, user.id)
          get "/u/#{other_user.username}.json"
        end

        it "should not track a user profile view for a user viewing his own profile" do
          UserProfileView.expects(:add).never
          get "/u/#{user.username}.json"
        end

        it "skips tracking" do
          UserProfileView.expects(:add).never
          get "/u/#{user.username}.json", params: { skip_track_visit: true }
        end
      end

      context "fetching a user by external_id" do
        before { user.create_single_sign_on_record(external_id: '997', last_payload: '') }

        it "returns fetch for a matching external_id" do
          get "/u/by-external/997.json"
          expect(response.status).to eq(200)
          expect(JSON.parse(response.body)["user"]["username"]).to eq(user.username)
        end

        it "returns not found when external_id doesn't match" do
          get "/u/by-external/99.json"
          expect(response).not_to be_successful
        end
      end

      describe "include_post_count_for" do

        fab!(:admin) { Fabricate(:admin) }
        fab!(:topic) { Fabricate(:topic) }

        before do
          Fabricate(:post, user: user, topic: topic)
          Fabricate(:post, user: admin, topic: topic)
          Fabricate(:post, user: admin, topic: topic, post_type: Post.types[:whisper])
        end

        it "includes only visible posts" do
          get "/u/#{admin.username}.json", params: { include_post_count_for: topic.id }
          topic_post_count = JSON.parse(response.body).dig("user", "topic_post_count")
          expect(topic_post_count[topic.id.to_s]).to eq(1)
        end

        it "includes all post types for staff members" do
          sign_in(admin)

          get "/u/#{admin.username}.json", params: { include_post_count_for: topic.id }
          topic_post_count = JSON.parse(response.body).dig("user", "topic_post_count")
          expect(topic_post_count[topic.id.to_s]).to eq(2)
        end
      end
    end

    it "should be able to view a user" do
      get "/u/#{user.username}"

      expect(response.status).to eq(200)
      expect(response.body).to include(user.username)
    end

    describe 'when username contains a period' do
      before do
        user.update!(username: 'test.test')
      end

      it "should be able to view a user" do
        get "/u/#{user.username}"

        expect(response.status).to eq(200)
        expect(response.body).to include(user.username)
      end
    end
  end

  describe '#badges' do
    it "renders fine by default" do
      get "/u/#{user.username}/badges"
      expect(response.status).to eq(200)
    end

    it "fails if badges are disabled" do
      SiteSetting.enable_badges = false
      get "/u/#{user.username}/badges"
      expect(response.status).to eq(404)
    end
  end

  describe "#account_created" do
    it "returns a message when no session is present" do
      get "/u/account-created"

      expect(response.status).to eq(200)

      body = response.body

      expect(body).to match(I18n.t('activation.missing_session'))
    end

    it "redirects when the user is logged in" do
      sign_in(Fabricate(:user))
      get "/u/account-created"

      expect(response).to redirect_to("/")
    end

    context 'when cookies contains a destination URL' do
      it 'should redirect to the URL' do
        sign_in(Fabricate(:user))
        destination_url = 'http://thisisasite.com/somepath'
        cookies[:destination_url] = destination_url

        get "/u/account-created"

        expect(response).to redirect_to(destination_url)
      end
    end

    context "when the user account is created" do
      include ApplicationHelper

      it "returns the message when set in the session" do
        user = create_user
        get "/u/account-created"

        expect(response.status).to eq(200)

        expect(response.body).to have_tag("div#data-preloaded") do |element|
          json = JSON.parse(element.current_scope.attribute('data-preloaded').value)
          expect(json['accountCreated']).to include(
            "{\"message\":\"#{I18n.t("login.activate_email", email: user.email).gsub!("</", "<\\/")}\",\"show_controls\":true,\"username\":\"#{user.username}\",\"email\":\"#{user.email}\"}"
          )
        end
      end
    end
  end

  describe '#search_users' do
    fab!(:topic) { Fabricate :topic }
    let(:user)  { Fabricate :user, username: "joecabot", name: "Lawrence Tierney" }
    let(:post1) { Fabricate(:post, user: user, topic: topic) }

    before do
      SearchIndexer.enable
      post1
    end

    it "searches when provided the term only" do
      get "/u/search/users.json", params: { term: user.name.split(" ").last }
      expect(response.status).to eq(200)
      json = JSON.parse(response.body)
      expect(json["users"].map { |u| u["username"] }).to include(user.username)
    end

    it "searches when provided the topic only" do
      get "/u/search/users.json", params: { topic_id: topic.id }
      expect(response.status).to eq(200)
      json = JSON.parse(response.body)
      expect(json["users"].map { |u| u["username"] }).to include(user.username)
    end

    it "searches when provided the term and topic" do
      get "/u/search/users.json", params: {
        term: user.name.split(" ").last, topic_id: topic.id
      }

      expect(response.status).to eq(200)
      json = JSON.parse(response.body)
      expect(json["users"].map { |u| u["username"] }).to include(user.username)
    end

    it "searches only for users who have access to private topic" do
      searching_user = Fabricate(:user)
      privileged_user = Fabricate(:user, trust_level: 4, username: "joecabit", name: "Lawrence Tierney")
      privileged_group = Fabricate(:group)
      privileged_group.add(searching_user)
      privileged_group.add(privileged_user)
      privileged_group.save

      category = Fabricate(:category)
      category.set_permissions(privileged_group => :readonly)
      category.save

      private_topic = Fabricate(:topic, category: category)

      sign_in(searching_user)
      get "/u/search/users.json", params: {
        term: user.name.split(" ").last, topic_id: private_topic.id, topic_allowed_users: "true"
      }

      expect(response.status).to eq(200)
      json = JSON.parse(response.body)
      expect(json["users"].map { |u| u["username"] }).to_not include(user.username)
      expect(json["users"].map { |u| u["username"] }).to include(privileged_user.username)
    end

    context "when `enable_names` is true" do
      before do
        SiteSetting.enable_names = true
      end

      it "returns names" do
        get "/u/search/users.json", params: { term: user.name }
        json = JSON.parse(response.body)
        expect(json["users"].map { |u| u["name"] }).to include(user.name)
      end
    end

    context "when `enable_names` is false" do
      before do
        SiteSetting.enable_names = false
      end

      it "returns names" do
        get "/u/search/users.json", params: { term: user.name }
        json = JSON.parse(response.body)
        expect(json["users"].map { |u| u["name"] }).not_to include(user.name)
      end
    end

    context 'groups' do
      let!(:mentionable_group) do
        Fabricate(:group,
          mentionable_level: 99,
          messageable_level: 0,
          visibility_level: 0,
          name: 'aaa1'
        )
      end

      let!(:mentionable_group_2) do
        Fabricate(:group,
          mentionable_level: 99,
          messageable_level: 0,
          visibility_level: 1,
          name: 'aaa2'
        )
      end

      let!(:messageable_group) do
        Fabricate(:group,
          mentionable_level: 0,
          messageable_level: 99,
          name: 'aaa3'
        )
      end

      describe 'when signed in' do
        before do
          sign_in(user)
        end

        it "does not search for groups if there is no term" do
          get "/u/search/users.json", params: { include_groups: "true" }

          expect(response.status).to eq(200)

          groups = JSON.parse(response.body)["groups"]
          expect(groups).to eq(nil)
        end

        it "only returns visible groups" do
          get "/u/search/users.json", params: { include_groups: "true", term: 'a' }

          expect(response.status).to eq(200)

          groups = JSON.parse(response.body)["groups"]

          expect(groups.map { |group| group['name'] })
            .to_not include(mentionable_group_2.name)
        end

        it "doesn't search for groups" do
          get "/u/search/users.json", params: {
            include_mentionable_groups: 'false',
            include_messageable_groups: 'false',
            term: 'a'
          }

          expect(response.status).to eq(200)
          expect(JSON.parse(response.body)).not_to have_key(:groups)
        end

        it "searches for messageable groups" do
          get "/u/search/users.json", params: {
            include_mentionable_groups: 'false',
            include_messageable_groups: 'true',
            term: 'a'
          }

          expect(response.status).to eq(200)

          expect(JSON.parse(response.body)["groups"].map { |group| group['name'] })
            .to contain_exactly(messageable_group.name, Group.find(Group::AUTO_GROUPS[:moderators]).name)
        end

        it 'searches for mentionable groups' do
          get "/u/search/users.json", params: {
            include_messageable_groups: 'false',
            include_mentionable_groups: 'true',
            term: 'a'
          }

          expect(response.status).to eq(200)

          groups = JSON.parse(response.body)["groups"]

          expect(groups.map { |group| group['name'] })
            .to contain_exactly(mentionable_group.name, mentionable_group_2.name)
        end
      end

      describe 'when not signed in' do
        it 'should not include mentionable/messageable groups' do
          get "/u/search/users.json", params: {
            include_mentionable_groups: 'false',
            include_messageable_groups: 'false',
            term: 'a'
          }

          expect(response.status).to eq(200)
          expect(JSON.parse(response.body)).not_to have_key(:groups)

          get "/u/search/users.json", params: {
            include_mentionable_groups: 'false',
            include_messageable_groups: 'true',
            term: 'a'
          }

          expect(response.status).to eq(200)
          expect(JSON.parse(response.body)).not_to have_key(:groups)

          get "/u/search/users.json", params: {
            include_messageable_groups: 'false',
            include_mentionable_groups: 'true',
            term: 'a'
          }

          expect(response.status).to eq(200)
          expect(JSON.parse(response.body)).not_to have_key(:groups)
        end
      end

      describe 'when searching by group name' do
        fab!(:exclusive_group) { Fabricate(:group) }

        it 'return results if the user is a group member' do
          exclusive_group.add(user)

          get "/u/search/users.json", params: {
            group: exclusive_group.name,
            term: user.username
          }

          expect(users_found).to contain_exactly(user.username)
        end

        it 'does not return results if the user is not a group member' do
          get "/u/search/users.json", params: {
            group: exclusive_group.name,
            term: user.username
          }

          expect(users_found).to be_empty
        end

        it 'returns results if the user is member of one of the groups' do
          exclusive_group.add(user)

          get "/u/search/users.json", params: {
            groups: [exclusive_group.name],
            term: user.username
          }

          expect(users_found).to contain_exactly(user.username)
        end

        it 'does not return results if the user is not a member of the groups' do
          get "/u/search/users.json", params: {
            groups: [exclusive_group.name],
            term: user.username
          }

          expect(users_found).to be_empty
        end

        def users_found
          JSON.parse(response.body)['users'].map { |u| u['username'] }
        end
      end
    end
  end

  describe '#user_preferences_redirect' do
    it 'requires the user to be logged in' do
      get '/user_preferences'
      expect(response.status).to eq(404)
    end

    it "redirects to their profile when logged in" do
      sign_in(user)
      get '/user_preferences'
      expect(response).to redirect_to("/u/#{user.username_lower}/preferences")
    end
  end

  describe '#email_login' do
    before do
      SiteSetting.enable_local_logins_via_email = true
    end

    it "enqueues the right email" do
      post "/u/email-login.json", params: { login: user.email }

      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['user_found']).to eq(true)

      job_args = Jobs::CriticalUserEmail.jobs.last["args"].first

      expect(job_args["user_id"]).to eq(user.id)
      expect(job_args["type"]).to eq("email_login")
      expect(job_args["email_token"]).to eq(user.email_tokens.last.token)
    end

    describe 'when enable_local_logins_via_email is disabled' do
      before do
        SiteSetting.enable_local_logins_via_email = false
      end

      it 'should return the right response' do
        post "/u/email-login.json", params: { login: user.email }

        expect(response.status).to eq(404)
      end
    end

    describe 'when username or email is not valid' do
      it 'should not enqueue the email to login' do
        post "/u/email-login.json", params: { login: '@random' }

        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)['user_found']).to eq(false)
        expect(Jobs::CriticalUserEmail.jobs).to eq([])
      end
    end

    describe 'when hide_email_address_taken is true' do
      it 'should return the right response' do
        SiteSetting.hide_email_address_taken = true
        post "/u/email-login.json", params: { login: user.email }

        expect(response.status).to eq(200)
        expect(JSON.parse(response.body).has_key?('user_found')).to eq(false)
      end
    end

    describe "when user is already logged in" do
      it 'should redirect to the root path' do
        sign_in(user)
        post "/u/email-login.json", params: { login: user.email }

        expect(response).to redirect_to("/")
      end
    end
  end

  describe '#create_second_factor_totp' do
    context 'when not logged in' do
      it 'should return the right response' do
        post "/users/second_factors.json", params: {
          password: 'wrongpassword'
        }

        expect(response.status).to eq(403)
      end
    end

    context 'when logged in' do
      before do
        sign_in(user)
      end

      describe 'create 2fa request' do
        it 'fails on incorrect password' do
          ApplicationController.any_instance.expects(:secure_session).returns("confirmed-password-#{user.id}" => "false")
          post "/users/create_second_factor_totp.json"

          expect(response.status).to eq(403)
        end

        describe 'when local logins are disabled' do
          it 'should return the right response' do
            SiteSetting.enable_local_logins = false

            post "/users/create_second_factor_totp.json"

            expect(response.status).to eq(404)
          end
        end

        describe 'when SSO is enabled' do
          it 'should return the right response' do
            SiteSetting.sso_url = 'http://someurl.com'
            SiteSetting.enable_sso = true

            post "/users/create_second_factor_totp.json"

            expect(response.status).to eq(404)
          end
        end

        it 'succeeds on correct password' do
          ApplicationController.any_instance.stubs(:secure_session).returns("confirmed-password-#{user.id}" => "true")
          post "/users/create_second_factor_totp.json"

          expect(response.status).to eq(200)

          response_body = JSON.parse(response.body)

          expect(response_body['key']).to be_present
          expect(response_body['qr']).to be_present
        end
      end
    end
  end

  describe '#update_second_factor' do
    let(:user_second_factor) { Fabricate(:user_second_factor_totp, user: user) }

    context 'when not logged in' do
      it 'should return the right response' do
        put "/users/second_factor.json"

        expect(response.status).to eq(403)
      end
    end

    context 'when logged in' do
      before do
        sign_in(user)
        user_second_factor
      end

      context 'when user has totp setup' do
        context 'when token is missing' do
          it 'returns the right response' do
            put "/users/second_factor.json", params: {
              disable: 'true',
              second_factor_target: UserSecondFactor.methods[:totp],
              id: user_second_factor.id
            }

            expect(response.status).to eq(403)
          end
        end

        context 'when token is valid' do
          before do
            ApplicationController.any_instance.stubs(:secure_session).returns("confirmed-password-#{user.id}" => "true")
          end
          it 'should allow second factor for the user to be renamed' do
            put "/users/second_factor.json", params: {
                  name: 'renamed',
                  second_factor_target: UserSecondFactor.methods[:totp],
                  id: user_second_factor.id
                }

            expect(response.status).to eq(200)
            expect(user.reload.user_second_factors.totps.first.name).to eq("renamed")
          end

          it 'should allow second factor for the user to be disabled' do
            put "/users/second_factor.json", params: {
                  disable: 'true',
                  second_factor_target: UserSecondFactor.methods[:totp],
                  id: user_second_factor.id
            }

            expect(response.status).to eq(200)
            expect(user.reload.user_second_factors.totps.first).to eq(nil)
          end
        end
      end

      context "when user is updating backup codes" do
        context 'when token is missing' do
          it 'returns the right response' do
            put "/users/second_factor.json", params: {
              second_factor_target: UserSecondFactor.methods[:backup_codes]
            }

            expect(response.status).to eq(403)
          end
        end

        context 'when token is valid' do
          before do
            ApplicationController.any_instance.stubs(:secure_session).returns("confirmed-password-#{user.id}" => "true")
          end
          it 'should allow second factor backup for the user to be disabled' do
            put "/users/second_factor.json", params: {
                  second_factor_target: UserSecondFactor.methods[:backup_codes],
                  disable: 'true'
            }

            expect(response.status).to eq(200)
            expect(user.reload.user_second_factors.backup_codes).to be_empty
          end
        end
      end
    end
  end

  describe '#create_second_factor_backup' do
    let(:user_second_factor) { Fabricate(:user_second_factor_totp, user: user) }

    context 'when not logged in' do
      it 'should return the right response' do
        put "/users/second_factors_backup.json", params: {
          second_factor_token: 'wrongtoken',
          second_factor_method: UserSecondFactor.methods[:totp]
        }

        expect(response.status).to eq(403)
      end
    end

    context 'when logged in' do
      before do
        sign_in(user)
      end

      describe 'create 2fa request' do
        it 'fails on incorrect password' do
          ApplicationController.any_instance.expects(:secure_session).returns("confirmed-password-#{user.id}" => "false")
          put "/users/second_factors_backup.json"

          expect(response.status).to eq(403)
        end

        describe 'when local logins are disabled' do
          it 'should return the right response' do
            SiteSetting.enable_local_logins = false

            put "/users/second_factors_backup.json"

            expect(response.status).to eq(404)
          end
        end

        describe 'when SSO is enabled' do
          it 'should return the right response' do
            SiteSetting.sso_url = 'http://someurl.com'
            SiteSetting.enable_sso = true

            put "/users/second_factors_backup.json"

            expect(response.status).to eq(404)
          end
        end

        it 'succeeds on correct password' do
          ApplicationController.any_instance.expects(:secure_session).returns("confirmed-password-#{user.id}" => "true")

          put "/users/second_factors_backup.json"

          expect(response.status).to eq(200)

          response_body = JSON.parse(response.body)

          expect(response_body['backup_codes'].length).to be(10)
        end
      end
    end
  end

  describe '#revoke_account' do
    fab!(:other_user) { Fabricate(:user) }
    it 'errors for unauthorised users' do
      post "/u/#{user.username}/preferences/revoke-account.json", params: {
        provider_name: 'facebook'
      }
      expect(response.status).to eq(403)

      sign_in(other_user)

      post "/u/#{user.username}/preferences/revoke-account.json", params: {
        provider_name: 'facebook'
      }
      expect(response.status).to eq(403)
    end

    context 'while logged in' do
      before do
        sign_in(user)
      end

      it 'returns an error when there is no matching account' do
        post "/u/#{user.username}/preferences/revoke-account.json", params: {
          provider_name: 'facebook'
        }
        expect(response.status).to eq(404)
      end

      context "with fake provider" do
        let(:authenticator) do
          Class.new(Auth::Authenticator) do
            attr_accessor :can_revoke
            def name
              "testprovider"
            end

            def enabled?
              true
            end

            def description_for_user(user)
              "an account"
            end

            def can_revoke?
              can_revoke
            end

            def revoke(user, skip_remote: false)
              true
            end
          end.new
        end

        before do
          DiscoursePluginRegistry.register_auth_provider(Auth::AuthProvider.new(authenticator: authenticator))
        end

        after do
          DiscoursePluginRegistry.reset!
        end

        it 'returns an error when revoking is not allowed' do
          authenticator.can_revoke = false

          post "/u/#{user.username}/preferences/revoke-account.json", params: {
            provider_name: 'testprovider'
          }
          expect(response.status).to eq(404)

          authenticator.can_revoke = true
          post "/u/#{user.username}/preferences/revoke-account.json", params: {
            provider_name: 'testprovider'
          }
          expect(response.status).to eq(200)
        end

        it 'works' do
          authenticator.can_revoke = true

          post "/u/#{user.username}/preferences/revoke-account.json", params: {
            provider_name: 'testprovider'
          }
          expect(response.status).to eq(200)
        end
      end

    end

  end

  describe '#revoke_auth_token' do

    context 'while logged in' do
      before do
        2.times { sign_in(user) }
      end

      it 'logs user out' do
        ids = user.user_auth_tokens.order(:created_at).pluck(:id)

        post "/u/#{user.username}/preferences/revoke-auth-token.json",
          params: { token_id: ids[0] }

        expect(response.status).to eq(200)

        user.user_auth_tokens.reload
        expect(user.user_auth_tokens.count).to eq(1)
        expect(user.user_auth_tokens.first.id).to eq(ids[1])
      end

      it 'does not let user log out of current session' do
        token = UserAuthToken.generate!(user_id: user.id)
        env = Rack::MockRequest.env_for("/", "HTTP_COOKIE" => "_t=#{token.unhashed_auth_token};")
        Guardian.any_instance.stubs(:request).returns(Rack::Request.new(env))

        post "/u/#{user.username}/preferences/revoke-auth-token.json", params: { token_id: token.id }

        expect(response.status).to eq(400)
      end

      it 'logs user out from everywhere if token_id is not present' do
        post "/u/#{user.username}/preferences/revoke-auth-token.json"

        expect(response.status).to eq(200)
        expect(user.user_auth_tokens.count).to eq(0)
      end

    end

  end

  describe '#list_second_factors' do
    before do
      sign_in(user)
    end

    context 'when SSO is enabled' do
      before do
        SiteSetting.sso_url = 'https://discourse.test/sso'
        SiteSetting.enable_sso = true
      end

      it 'does not allow access' do
        post "/u/second_factors.json"
        expect(response.status).to eq(404)
      end
    end

    context 'when local logins are not enabled' do
      before do
        SiteSetting.enable_local_logins = false
      end

      it 'does not allow access' do
        post "/u/second_factors.json"
        expect(response.status).to eq(404)
      end
    end

    context 'when the site settings allow second factors' do
      before do
        SiteSetting.enable_local_logins = true
        SiteSetting.enable_sso = false
      end

      context 'when the password parameter is not provided' do
        let(:password) { '' }

        before do
          post "/u/second_factors.json", params: { password: password }
        end

        it 'returns password required response' do
          expect(response.status).to eq(200)
          response_body = JSON.parse(response.body)
          expect(response_body['password_required']).to eq(true)
        end
      end

      context 'when the password is provided' do
        let(:user) { Fabricate(:user, password: '8555039dd212cc66ec68') }

        context 'when the password is correct' do
          let(:password) { '8555039dd212cc66ec68' }

          it 'returns a list of enabled totps and security_key second factors' do
            totp_second_factor = Fabricate(:user_second_factor_totp, user: user)
            security_key_second_factor = Fabricate(:user_security_key, user: user, factor_type: UserSecurityKey.factor_types[:second_factor])

            post "/u/second_factors.json", params: { password: password }

            expect(response.status).to eq(200)
            response_body = JSON.parse(response.body)
            expect(response_body['totps'].map { |second_factor| second_factor['id'] }).to include(totp_second_factor.id)
            expect(response_body['security_keys'].map { |second_factor| second_factor['id'] }).to include(security_key_second_factor.id)
          end
        end

        context 'when the password is not correct' do
          let(:password) { 'wrongpassword' }

          it 'returns the incorrect password response' do

            post "/u/second_factors.json", params: { password: password }

            response_body = JSON.parse(response.body)
            expect(response_body['error']).to eq(
              I18n.t("login.incorrect_password")
            )
          end
        end
      end
    end
  end
end
