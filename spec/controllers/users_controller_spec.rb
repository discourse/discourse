require 'rails_helper'

describe UsersController do

  describe '.show' do

    context "anon" do

      let(:user) { Discourse.system_user }

      it "returns success" do
        get :show, params: { username: user.username }, format: :json
        expect(response).to be_success
      end

      it "should redirect to login page for anonymous user when profiles are hidden" do
        SiteSetting.hide_user_profiles_from_public = true
        get :show, params: { username: user.username }, format: :json
        expect(response).to redirect_to '/login'
      end

    end

    context "logged in" do

      let(:user) { log_in }

      it 'returns success' do
        get :show, params: { username: user.username, format: :json }, format: :json
        expect(response).to be_success
        json = JSON.parse(response.body)

        expect(json["user"]["has_title_badges"]).to eq(false)
      end

      it "returns not found when the username doesn't exist" do
        get :show, params: { username: 'madeuppity' }, format: :json
        expect(response).not_to be_success
      end

      it 'returns not found when the user is inactive' do
        inactive = Fabricate(:user, active: false)
        get :show, params: { username: inactive.username }, format: :json
        expect(response).not_to be_success
      end

      it 'returns success when show_inactive_accounts is true and user is logged in' do
        SiteSetting.show_inactive_accounts = true
        log_in_user(user)
        inactive = Fabricate(:user, active: false)
        get :show, params: { username: inactive.username }, format: :json
        expect(response).to be_success
      end

      it "raises an error on invalid access" do
        Guardian.any_instance.expects(:can_see?).with(user).returns(false)
        get :show, params: { username: user.username }, format: :json
        expect(response).to be_forbidden
      end

      describe "user profile views" do
        let(:other_user) { Fabricate(:user) }

        it "should track a user profile view for a signed in user" do
          UserProfileView.expects(:add).with(other_user.user_profile.id, request.remote_ip, user.id)
          get :show, params: { username: other_user.username }, format: :json
        end

        it "should not track a user profile view for a user viewing his own profile" do
          UserProfileView.expects(:add).never
          get :show, params: { username: user.username }, format: :json
        end

        it "should track a user profile view for an anon user" do
          UserProfileView.expects(:add).with(other_user.user_profile.id, request.remote_ip, nil)
          get :show, params: { username: other_user.username }, format: :json
        end

        it "skips tracking" do
          UserProfileView.expects(:add).never
          get :show, params: { username: user.username, skip_track_visit: true }, format: :json
        end
      end

      context "fetching a user by external_id" do
        before { user.create_single_sign_on_record(external_id: '997', last_payload: '') }

        it "returns fetch for a matching external_id" do
          get :show, params: { external_id: '997' }, format: :json
          expect(response).to be_success
        end

        it "returns not found when external_id doesn't match" do
          get :show, params: { external_id: '99' }, format: :json
          expect(response).not_to be_success
        end
      end

      describe "include_post_count_for" do

        let(:admin) { Fabricate(:admin) }
        let(:topic) { Fabricate(:topic) }

        before do
          Fabricate(:post, user: user, topic: topic)
          Fabricate(:post, user: admin, topic: topic)
          Fabricate(:post, user: admin, topic: topic, post_type: Post.types[:whisper])
        end

        it "includes only visible posts" do
          get :show,
            params: { username: admin.username, include_post_count_for: topic.id },
            format: :json

          topic_post_count = JSON.parse(response.body).dig("user", "topic_post_count")
          expect(topic_post_count[topic.id.to_s]).to eq(1)
        end

        it "includes all post types for staff members" do
          log_in_user(admin)

          get :show,
            params: { username: admin.username, include_post_count_for: topic.id },
            format: :json

          topic_post_count = JSON.parse(response.body).dig("user", "topic_post_count")
          expect(topic_post_count[topic.id.to_s]).to eq(2)
        end
      end
    end
  end

  describe '.activate_account' do
    before do
      UsersController.any_instance.stubs(:honeypot_or_challenge_fails?).returns(false)
    end

    context 'invalid token' do

      it 'return success' do
        EmailToken.expects(:confirm).with('asdfasdf').returns(nil)
        put :perform_account_activation, params: { token: 'asdfasdf' }
        expect(response).to be_success
        expect(flash[:error]).to be_present
      end
    end

    context 'valid token' do
      let(:user) { Fabricate(:user) }

      context 'welcome message' do
        before do
          EmailToken.expects(:confirm).with('asdfasdf').returns(user)
        end

        it 'enqueues a welcome message if the user object indicates so' do
          user.send_welcome_message = true
          user.expects(:enqueue_welcome_message).with('welcome_user')

          put :perform_account_activation, params: { token: 'asdfasdf' }
        end

        it "doesn't enqueue the welcome message if the object returns false" do
          user.send_welcome_message = false
          user.expects(:enqueue_welcome_message).with('welcome_user').never

          put :perform_account_activation, params: { token: 'asdfasdf' }
        end
      end

      context "honeypot" do
        it "raises an error if the honeypot is invalid" do
          UsersController.any_instance.stubs(:honeypot_or_challenge_fails?).returns(true)
          put :perform_account_activation, params: { token: 'asdfasdf' }, format: :json
          expect(response).not_to be_success
        end
      end

      context 'response' do
        render_views

        before do
          Guardian.any_instance.expects(:can_access_forum?).returns(true)
          EmailToken.expects(:confirm).with('asdfasdf').returns(user)
        end

        it 'correctly logs on user' do
          events = DiscourseEvent.track_events do
            put :perform_account_activation, params: { token: 'asdfasdf' }
          end

          expect(events.map { |event| event[:event_name] }).to include(
            :user_logged_in, :user_first_logged_in
          )

          expect(response).to be_success
          expect(flash[:error]).to be_blank
          expect(session[:current_user_id]).to be_present

          expect(response).to be_success

          expect(CGI.unescapeHTML(response.body))
            .to_not include(I18n.t('activation.approval_required'))
        end

      end

      context 'user is not approved' do
        render_views

        before do
          SiteSetting.must_approve_users = true
          EmailToken.expects(:confirm).with('asdfasdf').returns(user)
          put :perform_account_activation, params: { token: 'asdfasdf' }
        end

        it 'should return the right response' do
          expect(response).to be_success

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
  end

  describe '#perform_account_activation' do
    describe 'when cookies contains a destination URL' do
      let(:token) { 'asdadwewq' }
      let(:user) { Fabricate(:user) }

      before do
        UsersController.any_instance.stubs(:honeypot_or_challenge_fails?).returns(false)
        EmailToken.expects(:confirm).with(token).returns(user)
      end

      it 'should redirect to the URL' do
        destination_url = 'http://thisisasite.com/somepath'
        request.cookies[:destination_url] = destination_url

        put :perform_account_activation, params: { token: token }

        expect(response).to redirect_to(destination_url)
      end
    end
  end

  describe '.password_reset' do
    let(:user) { Fabricate(:user) }

    context "you can view it even if login is required" do
      it "returns success" do
        SiteSetting.login_required = true
        get :password_reset, params: { token: 'asdfasdf' }
        expect(response).to be_success
      end
    end

    context 'missing token' do
      render_views

      before do
        get :password_reset, params: { token: SecureRandom.hex }
      end

      it 'disallows login' do
        expect(response).to be_success

        expect(CGI.unescapeHTML(response.body))
          .to include(I18n.t('password_reset.no_token'))

        expect(response.body).to_not have_tag(:script, with: {
          src: '/assets/application.js'
        })

        expect(session[:current_user_id]).to be_blank
      end
    end

    context 'invalid token' do
      render_views

      it 'disallows login' do
        get :password_reset, params: { token: "evil_trout!" }

        expect(response).to be_success

        expect(CGI.unescapeHTML(response.body))
          .to include(I18n.t('password_reset.no_token'))

        expect(response.body).to_not have_tag(:script, with: {
          src: '/assets/application.js'
        })

        expect(session[:current_user_id]).to be_blank
      end

      it "responds with proper error message" do
        put :password_reset, params: {
          token: "evil_trout!", password: "awesomeSecretPassword"
        }, format: :json

        expect(response).to be_success
        expect(JSON.parse(response.body)["message"]).to eq(I18n.t('password_reset.no_token'))
        expect(session[:current_user_id]).to be_blank
      end
    end

    context 'valid token' do
      render_views

      context 'when rendered' do
        it 'renders referrer never on get requests' do
          user = Fabricate(:user)
          token = user.email_tokens.create(email: user.email).token
          get :password_reset, params: { token: token }

          expect(response.body).to include('<meta name="referrer" content="never">')
        end
      end

      it 'returns success' do
        user = Fabricate(:user)
        user_auth_token = UserAuthToken.generate!(user_id: user.id)
        token = user.email_tokens.create(email: user.email).token
        get :password_reset, params: { token: token }

        events = DiscourseEvent.track_events do
          put :password_reset,
            params: { token: token, password: 'hg9ow8yhg98o' }
        end

        expect(events.map { |event| event[:event_name] }).to include(
          :user_logged_in, :user_first_logged_in
        )

        expect(response).to be_success
        expect(response.body).to include('{"is_developer":false,"admin":false,"second_factor_required":false}')

        user.reload

        expect(session["password-#{token}"]).to be_blank
        expect(UserAuthToken.where(id: user_auth_token.id).count).to eq(0)
      end

      it 'disallows double password reset' do
        user = Fabricate(:user)
        token = user.email_tokens.create(email: user.email).token

        get :password_reset, params: { token: token }

        put :password_reset,
          params: { token: token, password: 'hg9ow8yHG32O' }

        put :password_reset,
          params: { token: token, password: 'test123987AsdfXYZ' }

        user.reload
        expect(user.confirm_password?('hg9ow8yHG32O')).to eq(true)

        # logged in now
        expect(user.user_auth_tokens.count).to eq(1)
      end

      it "doesn't redirect to wizard on get" do
        user = Fabricate(:admin)
        UserAuthToken.generate!(user_id: user.id)

        token = user.email_tokens.create(email: user.email).token
        get :password_reset, params: { token: token }, format: :json
        expect(response).not_to redirect_to(wizard_path)
      end

      it "redirects to the wizard if you're the first admin" do
        user = Fabricate(:admin)
        UserAuthToken.generate!(user_id: user.id)

        token = user.email_tokens.create(email: user.email).token
        get :password_reset, params: { token: token }

        put :password_reset, params: {
          token: token, password: 'hg9ow8yhg98oadminlonger'
        }

        expect(response).to redirect_to(wizard_path)
      end

      it "doesn't invalidate the token when loading the page" do
        user = Fabricate(:user)
        user_token = UserAuthToken.generate!(user_id: user.id)

        email_token = user.email_tokens.create(email: user.email)

        get :password_reset, params: { token: email_token.token }, format: :json

        email_token.reload

        expect(email_token.confirmed).to eq(false)
        expect(UserAuthToken.where(id: user_token.id).count).to eq(1)
      end

      context '2 factor authentication required' do
        let!(:second_factor) { Fabricate(:user_second_factor, user: user) }

        it 'does not change with an invalid token' do
          token = user.email_tokens.create!(email: user.email).token

          get :password_reset, params: { token: token }

          expect(response.body).to include('{"is_developer":false,"admin":false,"second_factor_required":true}')

          put :password_reset,
              params: { token: token, password: 'hg9ow8yHG32O', second_factor_token: '000000' }

          expect(response.body).to include(I18n.t("login.invalid_second_factor_code"))

          user.reload
          expect(user.confirm_password?('hg9ow8yHG32O')).not_to eq(true)
          expect(user.user_auth_tokens.count).not_to eq(1)
        end

        it 'changes password with valid 2-factor tokens' do
          token = user.email_tokens.create(email: user.email).token

          get :password_reset, params: { token: token }

          put :password_reset, params: {
            token: token,
            password: 'hg9ow8yHG32O',
            second_factor_token: ROTP::TOTP.new(second_factor.data).now
          }

          user.reload
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
        put :password_reset, params: {
          token: token, password: ''
        }, format: :json

        expect(response).to be_success
        expect(JSON.parse(response.body)["errors"]).to be_present
        expect(session[:current_user_id]).to be_blank
      end

      it "fails when the password is too long" do
        put :password_reset, params: {
          token: token, password: ('x' * (User.max_password_length + 1))
        }, format: :json

        expect(response).to be_success
        expect(JSON.parse(response.body)["errors"]).to be_present
        expect(session[:current_user_id]).to be_blank
      end

      it "logs in the user" do
        put :password_reset, params: {
          token: token, password: 'ksjafh928r'
        }, format: :json

        expect(response).to be_success
        expect(JSON.parse(response.body)["errors"]).to be_blank
        expect(session[:current_user_id]).to be_present
      end

      it "doesn't log in the user when not approved" do
        SiteSetting.must_approve_users = true
        put :password_reset, params: {
          token: token, password: 'ksjafh928r'
        }, format: :json

        expect(JSON.parse(response.body)["errors"]).to be_blank
        expect(session[:current_user_id]).to be_blank
      end
    end
  end

  describe '.confirm_email_token' do
    let(:user) { Fabricate(:user) }

    it "token doesn't match any records" do
      email_token = user.email_tokens.create(email: user.email)
      get :confirm_email_token, params: { token: SecureRandom.hex }, format: :json
      expect(response).to be_success
      expect(email_token.reload.confirmed).to eq(false)
    end

    it "token matches" do
      email_token = user.email_tokens.create(email: user.email)
      get :confirm_email_token, params: { token: email_token.token }, format: :json
      expect(response).to be_success
      expect(email_token.reload.confirmed).to eq(true)
    end
  end

  describe '#admin_login' do
    let(:admin) { Fabricate(:admin) }
    let(:user) { Fabricate(:user) }

    context 'enqueues mail' do
      it 'enqueues mail with admin email and sso enabled' do
        Jobs.expects(:enqueue).with(:critical_user_email, has_entries(type: :admin_login, user_id: admin.id))
        put :admin_login, params: { email: admin.email }
      end
    end

    context 'when email is incorrect' do
      render_views

      it 'should return the right response' do
        put :admin_login, params: { email: 'random' }

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
        get :admin_login, params: { token: "invalid" }
        expect(session[:current_user_id]).to be_blank
      end

      context 'valid token' do
        it 'does log in admin with SSO disabled' do
          SiteSetting.enable_sso = false
          token = admin.email_tokens.create(email: admin.email).token

          get :admin_login, params: { token: token }
          expect(response).to redirect_to('/')
          expect(session[:current_user_id]).to eq(admin.id)
        end

        it 'logs in admin with SSO enabled' do
          SiteSetting.sso_url = "https://www.example.com/sso"
          SiteSetting.enable_sso = true
          token = admin.email_tokens.create(email: admin.email).token

          get :admin_login, params: { token: token }
          expect(response).to redirect_to('/')
          expect(session[:current_user_id]).to eq(admin.id)
        end
      end

      describe 'when 2 factor authentication is enabled' do
        let(:second_factor) { Fabricate(:user_second_factor, user: admin) }
        let(:email_token) { Fabricate(:email_token, user: admin) }
        render_views

        it 'does not log in when token required' do
          second_factor
          get :admin_login, params: { token: email_token.token }
          expect(response).not_to redirect_to('/')
          expect(session[:current_user_id]).not_to eq(admin.id)
          expect(response.body).to include(I18n.t('login.second_factor_description'));
        end

        describe 'invalid 2 factor token' do
          it 'should display the right error' do
            second_factor

            put :admin_login, params: {
              token: email_token.token,
              second_factor_token: '13213'
            }

            expect(response.status).to eq(200)
            expect(response.body).to include(I18n.t('login.second_factor_description'));
            expect(response.body).to include(I18n.t('login.invalid_second_factor_code'));
          end
        end

        it 'logs in when a valid 2-factor token is given' do
          put :admin_login, params: {
            token: email_token.token,
            second_factor_token: ROTP::TOTP.new(second_factor.data).now
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

      user = log_in
      user.trust_level = 1
      user.save

      post :toggle_anon, format: :json
      expect(response).to be_success
      expect(session[:current_user_id]).to eq(AnonymousShadowCreator.get(user).id)

      post :toggle_anon, format: :json
      expect(response).to be_success
      expect(session[:current_user_id]).to eq(user.id)

    end
  end

  describe '#create' do

    before do
      UsersController.any_instance.stubs(:honeypot_value).returns(nil)
      UsersController.any_instance.stubs(:challenge_value).returns(nil)
      SiteSetting.allow_new_registrations = true
      @user = Fabricate.build(:user)
      @user.password = "strongpassword"
    end

    let(:post_user_params) do
      { name: @user.name,
        username: @user.username,
        password: "strongpassword",
        email: @user.email }
    end

    def post_user
      post :create, params: post_user_params, format: :json
    end

    context 'when email params is missing' do
      it 'should raise the right error' do
        expect do
          post :create, params: {
            name: @user.name,
            username: @user.username,
            passsword: 'tesing12352343'
          }, format: :json
        end.to raise_error(ActionController::ParameterMissing)
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

      it 'returns a 500 when local logins are disabled' do
        SiteSetting.enable_local_logins = false
        post_user

        expect(response.status).to eq(500)
      end

      it 'returns an error when new registrations are disabled' do
        SiteSetting.allow_new_registrations = false
        post_user
        json = JSON.parse(response.body)
        expect(json['success']).to eq(false)
        expect(json['message']).to be_present
      end

      it 'creates a user correctly' do
        Jobs.expects(:enqueue).with(:critical_user_email, has_entries(type: :signup))
        User.any_instance.expects(:enqueue_welcome_message).with('welcome_user').never

        post_user

        expect(JSON.parse(response.body)['active']).to be_falsey

        # should save user_created_message in session
        expect(session["user_created_message"]).to be_present
        expect(session[SessionController::ACTIVATE_USER_KEY]).to be_present
      end

      context "`must approve users` site setting is enabled" do
        before { SiteSetting.must_approve_users = true }

        it 'creates a user correctly' do
          Jobs.expects(:enqueue).with(:critical_user_email, has_entries(type: :signup))
          User.any_instance.expects(:enqueue_welcome_message).with('welcome_user').never

          post_user

          expect(JSON.parse(response.body)['active']).to be_falsey

          # should save user_created_message in session
          expect(session["user_created_message"]).to be_present
          expect(session[SessionController::ACTIVATE_USER_KEY]).to be_present
        end
      end

      context 'users already exists with given email' do
        let!(:existing) { Fabricate(:user, email: post_user_params[:email]) }

        it 'returns an error if hide_email_address_taken is disabled' do
          SiteSetting.hide_email_address_taken = false
          post_user
          json = JSON.parse(response.body)
          expect(json['success']).to eq(false)
          expect(json['message']).to be_present
        end

        it 'returns success if hide_email_address_taken is enabled' do
          SiteSetting.hide_email_address_taken = true
          expect {
            post_user
          }.to_not change { User.count }
          json = JSON.parse(response.body)
          expect(json['active']).to be_falsey
          expect(session["user_created_message"]).to be_present
        end
      end
    end

    context "creating as active" do
      it "won't create the user as active" do
        post :create, params: post_user_params.merge(active: true), format: :json
        expect(JSON.parse(response.body)['active']).to be_falsey
      end

      context "with a regular api key" do
        let(:user) { Fabricate(:user) }
        let(:api_key) { Fabricate(:api_key, user: user) }

        it "won't create the user as active with a regular key" do
          post :create,
            params: post_user_params.merge(active: true, api_key: api_key.key),
            format: :json

          expect(JSON.parse(response.body)['active']).to be_falsey
        end
      end

      context "with an admin api key" do
        let(:admin) { Fabricate(:admin) }
        let(:api_key) { Fabricate(:api_key, user: admin) }

        it "creates the user as active with a regular key" do
          SiteSetting.queue_jobs = true
          SiteSetting.send_welcome_message = true
          SiteSetting.must_approve_users = true

          Sidekiq::Client.expects(:enqueue).never

          post :create,
            params: post_user_params.merge(approved: true, active: true, api_key: api_key.key),
            format: :json

          json = JSON.parse(response.body)

          new_user = User.find(json["user_id"])

          expect(json['active']).to be_truthy

          expect(new_user.active).to eq(true)
          expect(new_user.approved).to eq(true)
          expect(new_user.approved_by_id).to eq(admin.id)
          expect(new_user.approved_at).to_not eq(nil)
        end

        it "won't create the developer as active" do
          UsernameCheckerService.expects(:is_developer?).returns(true)

          post :create,
            params: post_user_params.merge(active: true, api_key: api_key.key),
            format: :json

          expect(JSON.parse(response.body)['active']).to be_falsy
        end
      end
    end

    context "creating as staged" do
      it "won't create the user as staged" do
        post :create,
          params: post_user_params.merge(staged: true),
          format: :json

        new_user = User.where(username: post_user_params[:username]).first
        expect(new_user.staged?).to eq(false)
      end

      context "with a regular api key" do
        let(:user) { Fabricate(:user) }
        let(:api_key) { Fabricate(:api_key, user: user) }

        it "won't create the user as staged with a regular key" do
          post :create,
            params: post_user_params.merge(staged: true, api_key: api_key.key),
            format: :json

          new_user = User.where(username: post_user_params[:username]).first
          expect(new_user.staged?).to eq(false)
        end
      end

      context "with an admin api key" do
        let(:user) { Fabricate(:admin) }
        let(:api_key) { Fabricate(:api_key, user: user) }

        it "creates the user as staged with a regular key" do
          post :create,
            params: post_user_params.merge(staged: true, api_key: api_key.key),
            format: :json

          new_user = User.where(username: post_user_params[:username]).first
          expect(new_user.staged?).to eq(true)
        end

        it "won't create the developer as staged" do
          UsernameCheckerService.expects(:is_developer?).returns(true)
          post :create,
            params: post_user_params.merge(staged: true, api_key: api_key.key),
            format: :json

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

        # should save user_created_message in session
        expect(session["user_created_message"]).to be_present
        expect(session[SessionController::ACTIVATE_USER_KEY]).to be_present
      end

      it "shows the 'active' message" do
        User.any_instance.expects(:enqueue_welcome_message)
        post_user
        expect(JSON.parse(response.body)['message']).to eq(
          I18n.t 'login.active'
        )
      end

      it "should be logged in" do
        User.any_instance.expects(:enqueue_welcome_message)
        post_user
        expect(session[:current_user_id]).to be_present
      end

      it 'indicates the user is active in the response' do
        User.any_instance.expects(:enqueue_welcome_message)
        post_user
        expect(JSON.parse(response.body)['active']).to be_truthy
      end

      it 'returns 500 status when new registrations are disabled' do
        SiteSetting.allow_new_registrations = false

        post_user

        json = JSON.parse(response.body)
        expect(json['success']).to eq(false)
        expect(json['message']).to be_present
      end

      context 'authentication records for' do

        it 'should create twitter user info if required' do
          SiteSetting.must_approve_users = true
          SiteSetting.enable_twitter_logins = true
          twitter_auth = { twitter_user_id: 42, twitter_screen_name: "bruce" }
          auth = session[:authentication] = {}
          auth[:authenticator_name] = 'twitter'
          auth[:extra_data] = twitter_auth

          post_user

          expect(TwitterUserInfo.count).to eq(1)
        end
      end

      it "returns an error when email has been changed from the validated email address" do
        auth = session[:authentication] = {}
        auth[:email_valid] = 'true'
        auth[:email] = 'therealone@gmail.com'
        post_user
        json = JSON.parse(response.body)
        expect(json['success']).to eq(false)
        expect(json['message']).to be_present
      end

      it "will create the user successfully if email validation is required" do
        auth = session[:authentication] = {}
        auth[:email] = post_user_params[:email]
        post_user
        json = JSON.parse(response.body)
        expect(json['success']).to eq(true)
      end
    end

    context 'after success' do
      before { post_user }

      it 'should succeed' do
        is_expected.to respond_with(:success)
      end

      it 'has the proper JSON' do
        json = JSON::parse(response.body)
        expect(json["success"]).to eq(true)
      end

      it 'should not result in an active account' do
        expect(User.find_by(username: @user.username).active).to eq(false)
      end
    end

    shared_examples 'honeypot fails' do
      it 'should not create a new user' do
        expect {
          post :create, params: create_params, format: :json
        }.to_not change { User.count }
      end

      it 'should not send an email' do
        User.any_instance.expects(:enqueue_welcome_message).never
        post :create, params: create_params, format: :json
      end

      it 'should say it was successful' do
        post :create, params: create_params, format: :json
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
        expect { post :create, params: create_params, format: :json }.to_not change { User.count }
      end

      it 'should report failed' do
        post :create, params: create_params, format: :json
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
      let(:create_params) { { name: @user.name, username: 'Reserved', email: @user.email, password: "x" * 20 } }
      before { SiteSetting.reserved_usernames = 'a|reserved|b' }
      after { SiteSetting.reserved_usernames = nil }
      include_examples 'failed signup'
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
          post :create, params: create_params, format: :json
          expect(response).to be_success
          inserted = User.find_by_email(@user.email)
          expect(inserted).to be_present
          expect(inserted.custom_fields).to be_present
          expect(inserted.custom_fields["user_field_#{user_field.id}"]).to eq('value1')
          expect(inserted.custom_fields["user_field_#{another_field.id}"]).to eq('value2')
          expect(inserted.custom_fields["user_field_#{optional_field.id}"]).to be_blank
        end

        it "should succeed with the optional field" do
          create_params[:user_fields][optional_field.id.to_s] = 'value3'
          post :create, params: create_params.merge(create_params), format: :json
          expect(response).to be_success
          inserted = User.find_by_email(@user.email)
          expect(inserted).to be_present
          expect(inserted.custom_fields).to be_present
          expect(inserted.custom_fields["user_field_#{user_field.id}"]).to eq('value1')
          expect(inserted.custom_fields["user_field_#{another_field.id}"]).to eq('value2')
          expect(inserted.custom_fields["user_field_#{optional_field.id}"]).to eq('value3')
        end

        it "trims excessively long fields" do
          create_params[:user_fields][optional_field.id.to_s] = ('x' * 3000)
          post :create, params: create_params.merge(create_params), format: :json
          expect(response).to be_success
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
          post :create, params: create_params, format: :json
          expect(response).to be_success
          inserted = User.find_by_email(@user.email)
          expect(inserted).to be_present
          expect(inserted.custom_fields).not_to be_present
          expect(inserted.custom_fields["user_field_#{user_field.id}"]).to be_blank
        end
      end
    end

  end

  context '#username' do
    it 'raises an error when not logged in' do
      put :username, params: { username: 'somename' }, format: :json
      expect(response.status).to eq(403)
    end

    context 'while logged in' do
      let(:old_username) { "OrigUsrname" }
      let(:new_username) { "#{old_username}1234" }
      let(:user) { Fabricate(:user, username: old_username) }

      before do
        user.username = old_username
        log_in_user(user)
      end

      it 'raises an error without a new_username param' do
        expect do
          put :username, params: { username: user.username }, format: :json
        end.to raise_error(ActionController::ParameterMissing)

        expect(user.reload.username).to eq(old_username)
      end

      it 'raises an error when you don\'t have permission to change the username' do
        Guardian.any_instance.expects(:can_edit_username?).with(user).returns(false)

        put :username, params: {
          username: user.username, new_username: new_username
        }, format: :json

        expect(response).to be_forbidden
        expect(user.reload.username).to eq(old_username)
      end

      it 'raises an error when change_username fails' do
        put :username,
          params: { username: user.username, new_username: '@' },
          format: :json

        expect(response).to_not be_success

        body = JSON.parse(response.body)

        expect(body['errors'].first).to include(I18n.t(
          'user.username.short', min: User.username_length.begin
        ))

        expect(user.reload.username).to eq(old_username)
      end

      it 'should succeed in normal circumstances' do
        put :username,
          params: { username: user.username, new_username: new_username },
          format: :json

        expect(response).to be_success
        expect(user.reload.username).to eq(new_username)
      end

      it 'should fail if the user is old' do
        # Older than the change period and >1 post
        user.created_at = Time.now - (SiteSetting.username_change_period + 1).days
        PostCreator.new(user,
          title: 'This is a test topic',
          raw: 'This is a test this is a test'
        ).create

        put :username, params: {
          username: user.username, new_username: new_username
        }, format: :json

        expect(response).to be_forbidden
        expect(user.reload.username).to eq(old_username)
      end

      it 'should create a staff action log when a staff member changes the username' do
        acting_user = Fabricate(:admin)
        log_in_user(acting_user)

        put :username, params: {
          username: user.username, new_username: new_username
        }, format: :json

        expect(response).to be_success
        expect(UserHistory.where(action: UserHistory.actions[:change_username], target_user_id: user.id, acting_user_id: acting_user.id)).to be_present
        expect(user.reload.username).to eq(new_username)
      end

      it 'should return a JSON response with the updated username' do
        put :username, params: {
          username: user.username, new_username: new_username
        }, format: :json

        expect(::JSON.parse(response.body)['username']).to eq(new_username)
      end

    end
  end

  context '.check_username' do
    it 'raises an error without any parameters' do
      expect do
        get :check_username, format: :json
      end.to raise_error(ActionController::ParameterMissing)
    end

    shared_examples 'when username is unavailable' do
      it 'should return success' do
        expect(response).to be_success
      end

      it 'should return available as false in the JSON' do
        expect(::JSON.parse(response.body)['available']).to eq(false)
      end

      it 'should return a suggested username' do
        expect(::JSON.parse(response.body)['suggestion']).to be_present
      end
    end

    shared_examples 'when username is available' do
      it 'should return success' do
        expect(response).to be_success
      end

      it 'should return available in the JSON' do
        expect(::JSON.parse(response.body)['available']).to eq(true)
      end
    end

    it 'returns nothing when given an email param but no username' do
      get :check_username, params: { email: 'dood@example.com' }, format: :json
      expect(response).to be_success
    end

    context 'username is available' do
      before do
        get :check_username, params: { username: 'BruceWayne' }, format: :json
      end
      include_examples 'when username is available'
    end

    context 'username is unavailable' do
      let!(:user) { Fabricate(:user) }
      before do
        get :check_username, params: { username: user.username }, format: :json
      end
      include_examples 'when username is unavailable'
    end

    shared_examples 'checking an invalid username' do
      it 'should return success' do
        expect(response).to be_success
      end

      it 'should not return an available key' do
        expect(::JSON.parse(response.body)['available']).to eq(nil)
      end

      it 'should return an error message' do
        expect(::JSON.parse(response.body)['errors']).not_to be_empty
      end
    end

    context 'has invalid characters' do
      before do
        get :check_username, params: {
          username: 'bad username'
        }, format: :json
      end
      include_examples 'checking an invalid username'

      it 'should return the invalid characters message' do
        expect(::JSON.parse(response.body)['errors']).to include(I18n.t(:'user.username.characters'))
      end
    end

    context 'is too long' do
      before do
        get :check_username, params: {
          username: generate_username(User.username_length.last + 1)
        }, format: :json
      end
      include_examples 'checking an invalid username'

      it 'should return the "too long" message' do
        expect(::JSON.parse(response.body)['errors']).to include(I18n.t(:'user.username.long', max: User.username_length.end))
      end
    end

    describe 'different case of existing username' do
      context "it's my username" do
        let!(:user) { Fabricate(:user, username: 'hansolo') }
        before do
          log_in_user(user)

          get :check_username, params: {
            username: 'HanSolo'
          }, format: :json
        end
        include_examples 'when username is available'
      end

      context "it's someone else's username" do
        let!(:user) { Fabricate(:user, username: 'hansolo') }
        before do
          log_in

          get :check_username, params: {
            username: 'HanSolo'
          }, format: :json
        end
        include_examples 'when username is unavailable'
      end

      context "an admin changing it for someone else" do
        let!(:user) { Fabricate(:user, username: 'hansolo') }
        before do
          log_in_user(Fabricate(:admin))

          get :check_username, params: {
            username: 'HanSolo', for_user_id: user.id
          }, format: :json
        end
        include_examples 'when username is available'
      end
    end
  end

  describe '#invited' do
    it 'returns success' do
      user = Fabricate(:user)
      get :invited, params: { username: user.username }, format: :json

      expect(response).to be_success
    end

    it 'filters by email' do
      inviter = Fabricate(:user)
      invitee = Fabricate(:user)
      _invite = Fabricate(
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

      get :invited, params: {
        username: inviter.username, search: 'billybob'
      }, format: :json

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

      get :invited, params: {
        username: inviter.username, search: 'billybob'
      }, format: :json

      invites = JSON.parse(response.body)['invites']
      expect(invites.size).to eq(1)
      expect(invites.first).to include('email' => 'billybob@example.com')
    end

    context 'with guest' do
      context 'with pending invites' do
        it 'does not return invites' do
          inviter = Fabricate(:user)
          Fabricate(:invite, invited_by: inviter)

          get :invited,
            params: { username: inviter.username, filter: 'pending' },
            format: :json

          invites = JSON.parse(response.body)['invites']
          expect(invites).to be_empty
        end
      end

      context 'with redeemed invites' do
        it 'returns invites' do
          inviter = Fabricate(:user)
          invitee = Fabricate(:user)
          invite = Fabricate(:invite, invited_by: inviter, user: invitee)

          get :invited,
            params: { username: inviter.username },
            format: :json

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
            user = log_in
            inviter = Fabricate(:user)
            invite = Fabricate(:invite, invited_by: inviter)
            stub_guardian(user) do |guardian|
              guardian.stubs(:can_see_invite_details?).
                with(inviter).returns(true)
            end

            get :invited, params: {
              username: inviter.username, filter: 'pending'
            }, format: :json

            invites = JSON.parse(response.body)['invites']
            expect(invites.size).to eq(1)
            expect(invites.first).to include("email" => invite.email)
          end
        end

        context 'without permission to see pending invites' do
          it 'does not return invites' do
            user = log_in
            inviter = Fabricate(:user)
            _invitee = Fabricate(:user)
            Fabricate(:invite, invited_by: inviter)
            stub_guardian(user) do |guardian|
              guardian.stubs(:can_see_invite_details?).
                with(inviter).returns(false)
            end

            get :invited, params: {
              username: inviter.username, filter: 'pending'
            }, format: :json

            json = JSON.parse(response.body)['invites']
            expect(json).to be_empty
          end
        end
      end

      context 'with redeemed invites' do
        it 'returns invites' do
          _user = log_in
          inviter = Fabricate(:user)
          invitee = Fabricate(:user)
          invite = Fabricate(:invite, invited_by: inviter, user: invitee)

          get :invited, params: { username: inviter.username }, format: :json

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
        put :update, params: { username: 'guest' }, format: :json
        expect(response.status).to eq(403)
      end
    end

    context "as a staff user" do
      let!(:user) { log_in(:admin) }

      context "uneditable field" do
        let!(:user_field) { Fabricate(:user_field, editable: false) }

        it "allows staff to edit the field" do
          put :update, params: {
            username: user.username,
            name: 'Jim Tom',
            title: "foobar",
            user_fields: { user_field.id.to_s => 'happy' }
          }, format: :json

          expect(response).to be_success

          user.reload

          expect(user.user_fields[user_field.id.to_s]).to eq('happy')
          expect(user.title).to eq("foobar")
        end
      end

    end

    context 'with authenticated user' do
      context 'with permission to update' do
        let!(:user) { log_in(:user) }

        it 'allows the update' do
          user2 = Fabricate(:user)
          user3 = Fabricate(:user)

          put :update, params: {
            username: user.username,
            name: 'Jim Tom',
            custom_fields: { test: :it },
            muted_usernames: "#{user2.username},#{user3.username}"
          }, format: :json

          expect(response).to be_success

          user.reload

          expect(user.name).to eq 'Jim Tom'
          expect(user.custom_fields['test']).to eq 'it'
          expect(user.muted_users.pluck(:username).sort).to eq [user2.username, user3.username].sort

          theme = Theme.create(name: "test", user_selectable: true, user_id: -1)

          put :update, params: {
            username: user.username,
            muted_usernames: "",
            theme_key: theme.key,
            email_direct: false
          }, format: :json

          user.reload

          expect(user.muted_users.pluck(:username).sort).to be_empty
          expect(user.user_option.theme_key).to eq(theme.key)
          expect(user.user_option.email_direct).to eq(false)
        end

        context 'a locale is chosen that differs from I18n.locale' do
          it "updates the user's locale" do
            I18n.stubs(:locale).returns('fr')

            put :update, params: {
              username: user.username,
              locale: :fa_IR
            }, format: :json

            expect(User.find_by(username: user.username).locale).to eq('fa_IR')
          end

        end

        context "with user fields" do
          context "an editable field" do
            let!(:user_field) { Fabricate(:user_field) }
            let!(:optional_field) { Fabricate(:user_field, required: false) }

            it "should update the user field" do
              put :update, params: {
                username: user.username, name: 'Jim Tom', user_fields: { user_field.id.to_s => 'happy' }
              }, format: :json

              expect(response).to be_success
              expect(user.user_fields[user_field.id.to_s]).to eq 'happy'
            end

            it "cannot be updated to blank" do
              put :update, params: {
                username: user.username, name: 'Jim Tom', user_fields: { user_field.id.to_s => '' }
              }, format: :json

              expect(response).not_to be_success
              expect(user.user_fields[user_field.id.to_s]).not_to eq('happy')
            end

            it "trims excessively large fields" do
              put :update, params: {
                username: user.username, name: 'Jim Tom', user_fields: { user_field.id.to_s => ('x' * 3000) }
              }, format: :json

              expect(user.user_fields[user_field.id.to_s].size).to eq(UserField.max_length)
            end

            it "should retain existing user fields" do
              put :update, params: {
                username: user.username, name: 'Jim Tom', user_fields: { user_field.id.to_s => 'happy', optional_field.id.to_s => 'feet' }
              }, format: :json

              expect(response).to be_success
              expect(user.user_fields[user_field.id.to_s]).to eq('happy')
              expect(user.user_fields[optional_field.id.to_s]).to eq('feet')

              put :update, params: {
                username: user.username, name: 'Jim Tom', user_fields: { user_field.id.to_s => 'sad' }
              }, format: :json

              expect(response).to be_success

              user.reload

              expect(user.user_fields[user_field.id.to_s]).to eq('sad')
              expect(user.user_fields[optional_field.id.to_s]).to eq('feet')
            end
          end

          context "uneditable field" do
            let!(:user_field) { Fabricate(:user_field, editable: false) }

            it "does not update the user field" do
              put :update, params: {
                username: user.username, name: 'Jim Tom', user_fields: { user_field.id.to_s => 'happy' }
              }, format: :json

              expect(response).to be_success
              expect(user.user_fields[user_field.id.to_s]).to be_blank
            end
          end

        end

        it 'returns user JSON' do
          put :update, params: { username: user.username }, format: :json

          json = JSON.parse(response.body)
          expect(json['user']['id']).to eq user.id
        end

      end

      context 'without permission to update' do
        it 'does not allow the update' do
          user = Fabricate(:user, name: 'Billy Bob')
          log_in_user(user)
          Guardian.any_instance.expects(:can_edit?).with(user).returns(false)

          put :update,
            params: { username: user.username, name: 'Jim Tom' },
            format: :json

          expect(response).to be_forbidden
          expect(user.reload.name).not_to eq 'Jim Tom'
        end
      end
    end
  end

  describe "badge_card" do
    let(:user) { Fabricate(:user) }
    let(:badge) { Fabricate(:badge) }
    let(:user_badge) { BadgeGranter.grant(badge, user) }

    it "sets the user's card image to the badge" do
      log_in_user user
      put :update_card_badge, params: {
        user_badge_id: user_badge.id, username: user.username
      }, format: :json

      expect(user.user_profile.reload.card_image_badge_id).to be_blank
      badge.update_attributes image: "wat.com/wat.jpg"

      put :update_card_badge, params: {
        user_badge_id: user_badge.id, username: user.username
      }, format: :json

      expect(user.user_profile.reload.card_image_badge_id).to eq(badge.id)

      # Can set to nothing
      put :update_card_badge, params: {
        username: user.username
      }, format: :json

      expect(user.user_profile.reload.card_image_badge_id).to be_blank
    end
  end

  describe "badge_title" do
    let(:user) { Fabricate(:user) }
    let(:badge) { Fabricate(:badge) }
    let(:user_badge) { BadgeGranter.grant(badge, user) }

    it "sets the user's title to the badge name if it is titleable" do
      log_in_user user

      put :badge_title, params: {
        user_badge_id: user_badge.id, username: user.username
      }, format: :json

      expect(user.reload.title).not_to eq(badge.display_name)
      badge.update_attributes allow_title: true

      put :badge_title, params: {
        user_badge_id: user_badge.id, username: user.username
      }, format: :json

      expect(user.reload.title).to eq(badge.display_name)
      expect(user.user_profile.badge_granted_title).to eq(true)

      user.title = "testing"
      user.save
      user.user_profile.reload
      expect(user.user_profile.badge_granted_title).to eq(false)

    end
  end

  describe "badge_title with overrided name" do
    let(:user) { Fabricate(:user) }
    let(:badge) { Fabricate(:badge, name: 'Demogorgon', allow_title: true) }
    let(:user_badge) { BadgeGranter.grant(badge, user) }

    before do
      TranslationOverride.upsert!('en', 'badges.demogorgon.name', 'Boss')
    end

    after do
      TranslationOverride.revert!('en', ['badges.demogorgon.name'])
    end

    it "uses the badge display name as user title" do
      log_in_user user

      put :badge_title, params: {
        user_badge_id: user_badge.id, username: user.username
      }, format: :json

      expect(user.reload.title).to eq(badge.display_name)
    end
  end

  describe 'send_activation_email' do
    context 'for an existing user' do
      let(:user) { Fabricate(:user, active: false) }

      context 'for an activated account with email confirmed' do
        it 'fails' do
          active_user = Fabricate(:user, active: true)
          email_token = active_user.email_tokens.create(email: active_user.email).token
          EmailToken.confirm(email_token)
          session[SessionController::ACTIVATE_USER_KEY] = active_user.id

          post :send_activation_email, params: {
            username: active_user.username
          }, format: :json

          expect(response.status).to eq(409)

          expect(JSON.parse(response.body)['errors']).to include(I18n.t(
            'activation.activated'
          ))

          expect(session[SessionController::ACTIVATE_USER_KEY]).to eq(nil)
        end
      end

      context 'for an activated account with unconfirmed email' do
        it 'should send an email' do
          unconfirmed_email_user = Fabricate(:user, active: true)
          unconfirmed_email_user.email_tokens.create(email: unconfirmed_email_user.email)
          session[SessionController::ACTIVATE_USER_KEY] = unconfirmed_email_user.id
          Jobs.expects(:enqueue).with(:critical_user_email, has_entries(type: :signup, to_address: unconfirmed_email_user.email))

          post :send_activation_email, params: {
            username: unconfirmed_email_user.username
          }, format: :json

          expect(response.status).to eq(200)

          expect(session[SessionController::ACTIVATE_USER_KEY]).to eq(nil)
        end
      end

      context "approval is enabled" do
        before do
          SiteSetting.must_approve_users = true
        end

        it "should raise an error" do
          unconfirmed_email_user = Fabricate(:user, active: true)
          unconfirmed_email_user.email_tokens.create(email: unconfirmed_email_user.email)
          session[SessionController::ACTIVATE_USER_KEY] = unconfirmed_email_user.id
          post :send_activation_email, params: {
            username: unconfirmed_email_user.username
          }, format: :json

          expect(response.status).to eq(403)
        end
      end

      describe 'when user does not have a valid session' do
        it 'should not be valid' do
          user = Fabricate(:user)
          post :send_activation_email, params: {
            username: user.username
          }, format: :json

          expect(response.status).to eq(403)
        end

        it 'should allow staff regardless' do
          log_in :admin
          user = Fabricate(:user, active: false)

          post :send_activation_email, params: {
            username: user.username
          }, format: :json

          expect(response.status).to eq(200)
        end
      end

      context 'with a valid email_token' do
        it 'should send the activation email' do
          session[SessionController::ACTIVATE_USER_KEY] = user.id
          Jobs.expects(:enqueue).with(:critical_user_email, has_entries(type: :signup))

          post :send_activation_email, params: {
            username: user.username
          }, format: :json

          expect(session[SessionController::ACTIVATE_USER_KEY]).to eq(nil)
        end
      end

      context 'without an existing email_token' do
        before do
          user.email_tokens.each { |t| t.destroy }
          user.reload
        end

        it 'should generate a new token' do
          expect {
            session[SessionController::ACTIVATE_USER_KEY] = user.id

            post :send_activation_email,
              params: { username: user.username },
              format: :json
          }.to change { user.reload.email_tokens.count }.by(1)
        end

        it 'should send an email' do
          session[SessionController::ACTIVATE_USER_KEY] = user.id
          Jobs.expects(:enqueue).with(:critical_user_email, has_entries(type: :signup))

          post :send_activation_email,
            params: { username: user.username },
            format: :json

          expect(session[SessionController::ACTIVATE_USER_KEY]).to eq(nil)
        end
      end
    end

    context 'when username does not exist' do
      it 'should not send an email' do
        Jobs.expects(:enqueue).never

        post :send_activation_email,
          params: { username: 'nopenopenopenope' },
          format: :json
      end
    end
  end

  describe '.pick_avatar' do

    it 'raises an error when not logged in' do
      put :pick_avatar, params: {
        username: 'asdf', avatar_id: 1, type: "custom"
      }, format: :json
      expect(response.status).to eq(403)
    end

    context 'while logged in' do

      let!(:user) { log_in }
      let(:upload) { Fabricate(:upload) }

      it "raises an error when you don't have permission to toggle the avatar" do
        another_user = Fabricate(:user)
        put :pick_avatar, params: {
          username: another_user.username, upload_id: upload.id, type: "custom"
        }, format: :json

        expect(response).to be_forbidden
      end

      it "raises an error when sso_overrides_avatar is disabled" do
        SiteSetting.sso_overrides_avatar = true
        put :pick_avatar, params: {
          username: user.username, upload_id: upload.id, type: "custom"
        }, format: :json

        expect(response).to_not be_success
      end

      it "raises an error when selecting the custom/uploaded avatar and allow_uploaded_avatars is disabled" do
        SiteSetting.allow_uploaded_avatars = false
        put :pick_avatar, params: {
          username: user.username, upload_id: upload.id, type: "custom"
        }, format: :json

        expect(response).to_not be_success
      end

      it 'can successfully pick the system avatar' do
        put :pick_avatar, params: {
          username: user.username
        }, format: :json

        expect(response).to be_success
        expect(user.reload.uploaded_avatar_id).to eq(nil)
      end

      it 'can successfully pick a gravatar' do
        put :pick_avatar, params: {
          username: user.username, upload_id: upload.id, type: "gravatar"
        }, format: :json

        expect(response).to be_success
        expect(user.reload.uploaded_avatar_id).to eq(upload.id)
        expect(user.user_avatar.reload.gravatar_upload_id).to eq(upload.id)
      end

      it 'can successfully pick a custom avatar' do
        put :pick_avatar, params: {
          username: user.username, upload_id: upload.id, type: "custom"
        }, format: :json

        expect(response).to be_success
        expect(user.reload.uploaded_avatar_id).to eq(upload.id)
        expect(user.user_avatar.reload.custom_upload_id).to eq(upload.id)
      end

    end

  end

  describe '.destroy_user_image' do

    it 'raises an error when not logged in' do
      delete :destroy_user_image,
        params: { type: 'profile_background', username: 'asdf' },
        format: :json
      expect(response.status).to eq(403)
    end

    context 'while logged in' do

      let!(:user) { log_in }

      it 'raises an error when you don\'t have permission to clear the profile background' do
        Guardian.any_instance.expects(:can_edit?).with(user).returns(false)

        delete :destroy_user_image,
          params: { username: user.username, type: 'profile_background' },
          format: :json

        expect(response).to be_forbidden
      end

      it "requires the `type` param" do
        expect do
          delete :destroy_user_image, params: { username: user.username }, format: :json
        end.to raise_error(ActionController::ParameterMissing)
      end

      it "only allows certain `types`" do
        delete :destroy_user_image,
          params: { username: user.username, type: 'wat' },
          format: :json
        expect(response.status).to eq(400)
      end

      it 'can clear the profile background' do
        delete :destroy_user_image, params: {
          type: 'profile_background', username: user.username
        }, format: :json

        expect(user.reload.user_profile.profile_background).to eq("")
        expect(response).to be_success
      end

    end
  end

  describe '.destroy' do
    it 'raises an error when not logged in' do
      delete :destroy, params: { username: 'nobody' }, format: :json
      expect(response.status).to eq(403)
    end

    context 'while logged in' do
      let!(:user) { log_in }

      it 'raises an error when you cannot delete your account' do
        Guardian.any_instance.stubs(:can_delete_user?).returns(false)
        UserDestroyer.any_instance.expects(:destroy).never
        delete :destroy, params: { username: user.username }, format: :json
        expect(response).to be_forbidden
      end

      it "raises an error when you try to delete someone else's account" do
        UserDestroyer.any_instance.expects(:destroy).never
        delete :destroy, params: { username: Fabricate(:user).username }, format: :json
        expect(response).to be_forbidden
      end

      it "deletes your account when you're allowed to" do
        Guardian.any_instance.stubs(:can_delete_user?).returns(true)
        UserDestroyer.any_instance.expects(:destroy).with(user, anything).returns(user)
        delete :destroy, params: { username: user.username }, format: :json
        expect(response).to be_success
      end
    end
  end

  describe '.my_redirect' do

    it "redirects if the user is not logged in" do
      get :my_redirect, params: { path: "wat" }, format: :json
      expect(response).not_to be_success
      expect(response).to be_redirect
    end

    context "when the user is logged in" do
      let!(:user) { log_in }

      it "will not redirect to an invalid path" do
        get :my_redirect, params: { path: "wat/..password.txt" }, format: :json
        expect(response).not_to be_redirect
      end

      it "will redirect to an valid path" do
        get :my_redirect, params: { path: "preferences" }, format: :json
        expect(response).to be_redirect
      end

      it "permits forward slashes" do
        get :my_redirect, params: { path: "activity/posts" }, format: :json
        expect(response).to be_redirect
      end
    end
  end

  describe '.check_emails' do

    it 'raises an error when not logged in' do
      put :check_emails, params: { username: 'zogstrip' }, format: :json
      expect(response.status).to eq(403)
    end

    context 'while logged in' do
      let!(:user) { log_in }

      it "raises an error when you aren't allowed to check emails" do
        Guardian.any_instance.expects(:can_check_emails?).returns(false)

        put :check_emails,
          params: { username: Fabricate(:user).username },
          format: :json

        expect(response).to be_forbidden
      end

      it "returns both email and associated_accounts when you're allowed to see them" do
        Guardian.any_instance.expects(:can_check_emails?).returns(true)

        put :check_emails,
          params: { username: Fabricate(:user).username },
          format: :json

        expect(response).to be_success
        json = JSON.parse(response.body)
        expect(json["email"]).to be_present
        expect(json["associated_accounts"]).to be_present
      end

      it "works on inactive users" do
        inactive_user = Fabricate(:user, active: false)
        Guardian.any_instance.expects(:can_check_emails?).returns(true)

        put :check_emails, params: {
          username: inactive_user.username
        }, format: :json

        expect(response).to be_success
        json = JSON.parse(response.body)
        expect(json["email"]).to be_present
        expect(json["associated_accounts"]).to be_present
      end

    end

  end

  describe ".is_local_username" do

    let(:user) { Fabricate(:user) }
    let(:group) { Fabricate(:group, name: "Discourse") }
    let(:topic) { Fabricate(:topic) }
    let(:allowed_user) { Fabricate(:user) }
    let(:private_topic) { Fabricate(:private_message_topic, user: allowed_user) }

    it "finds the user" do
      get :is_local_username, params: {
        username: user.username
      }, format: :json

      expect(response).to be_success
      json = JSON.parse(response.body)
      expect(json["valid"][0]).to eq(user.username)
    end

    it "finds the group" do
      get :is_local_username, params: {
        username: group.name
      }, format: :json

      expect(response).to be_success
      json = JSON.parse(response.body)
      expect(json["valid_groups"][0]).to eq(group.name)
    end

    it "supports multiples usernames" do
      get :is_local_username, params: {
        usernames: [user.username, "system"]
      }, format: :json

      expect(response).to be_success
      json = JSON.parse(response.body)
      expect(json["valid"].size).to eq(2)
    end

    it "never includes staged accounts" do
      staged = Fabricate(:user, staged: true)

      get :is_local_username, params: {
        usernames: [staged.username]
      }, format: :json

      expect(response).to be_success
      json = JSON.parse(response.body)
      expect(json["valid"].size).to eq(0)
    end

    it "returns user who cannot see topic" do
      Guardian.any_instance.expects(:can_see?).with(topic).returns(false)

      get :is_local_username, params: {
        usernames: [user.username], topic_id: topic.id
      }, format: :json

      expect(response).to be_success
      json = JSON.parse(response.body)
      expect(json["cannot_see"].size).to eq(1)
    end

    it "never returns a user who can see the topic" do
      Guardian.any_instance.expects(:can_see?).with(topic).returns(true)

      get :is_local_username, params: {
        usernames: [user.username], topic_id: topic.id
      }, format: :json

      expect(response).to be_success
      json = JSON.parse(response.body)
      expect(json["cannot_see"].size).to eq(0)
    end

    it "returns user who cannot see a private topic" do
      Guardian.any_instance.expects(:can_see?).with(private_topic).returns(false)

      get :is_local_username, params: {
        usernames: [user.username], topic_id: private_topic.id
      }, format: :json

      expect(response).to be_success
      json = JSON.parse(response.body)
      expect(json["cannot_see"].size).to eq(1)
    end

    it "never returns a user who can see the topic" do
      Guardian.any_instance.expects(:can_see?).with(private_topic).returns(true)

      get :is_local_username, params: {
        usernames: [allowed_user.username], topic_id: private_topic.id
      }, format: :json

      expect(response).to be_success
      json = JSON.parse(response.body)
      expect(json["cannot_see"].size).to eq(0)
    end

  end

  describe '.topic_tracking_state' do
    let(:user) { Fabricate(:user) }

    context 'anon' do
      it "raises an error on anon for topic_tracking_state" do
        get :topic_tracking_state, params: { username: user.username }, format: :json
        expect(response.status).to eq(403)
      end
    end

    context 'logged on' do
      it "detects new topic" do
        log_in_user(user)

        topic = Fabricate(:topic)
        get :topic_tracking_state, params: { username: user.username }, format: :json

        states = JSON.parse(response.body)

        expect(states[0]["topic_id"]).to eq(topic.id)
      end
    end
  end

  describe '.summary' do

    it "generates summary info" do
      user = Fabricate(:user)
      create_post(user: user)

      get :summary, params: { username: user.username_lower }, format: :json
      expect(response).to be_success
      json = JSON.parse(response.body)

      expect(json["user_summary"]["topic_count"]).to eq(1)
      expect(json["user_summary"]["post_count"]).to eq(0)
    end
  end

  describe ".confirm_admin" do
    it "fails without a valid token" do
      expect {
        get :confirm_admin, params: { token: 'invalid-token' }, format: :json
      }.to raise_error(ActionController::UrlGenerationError)
    end

    it "fails with a missing token" do
      get :confirm_admin, params: { token: 'a0a0a0a0a0' }, format: :json
      expect(response).to_not be_success
    end

    it "succeeds with a valid code as anonymous" do
      user = Fabricate(:user)
      ac = AdminConfirmation.new(user, Fabricate(:admin))
      ac.create_confirmation
      get :confirm_admin, params: { token: ac.token }
      expect(response).to be_success

      user.reload
      expect(user.admin?).to eq(false)
    end

    it "succeeds with a valid code when logged in as that user" do
      admin = log_in(:admin)
      user = Fabricate(:user)

      ac = AdminConfirmation.new(user, admin)
      ac.create_confirmation
      get :confirm_admin, params: { token: ac.token }
      expect(response).to be_success

      user.reload
      expect(user.admin?).to eq(false)
    end

    it "fails if you're logged in as a different account" do
      log_in(:admin)
      user = Fabricate(:user)

      ac = AdminConfirmation.new(user, Fabricate(:admin))
      ac.create_confirmation
      get :confirm_admin, params: { token: ac.token }, format: :json
      expect(response).to_not be_success

      user.reload
      expect(user.admin?).to eq(false)
    end

    describe "post" do
      it "gives the user admin access when POSTed" do
        user = Fabricate(:user)
        ac = AdminConfirmation.new(user, Fabricate(:admin))
        ac.create_confirmation
        post :confirm_admin, params: { token: ac.token }
        expect(response).to be_success

        user.reload
        expect(user.admin?).to eq(true)
      end
    end

  end

  describe '.update_activation_email' do

    context "with a session variable" do

      it "raises an error with an invalid session value" do
        session[SessionController::ACTIVATE_USER_KEY] = 1234

        put :update_activation_email, params: {
          email: 'updatedemail@example.com'
        }, format: :json

        expect(response).to_not be_success
      end

      it "raises an error for an active user" do
        user = Fabricate(:walter_white)
        session[SessionController::ACTIVATE_USER_KEY] = user.id

        put :update_activation_email, params: {
          email: 'updatedemail@example.com'
        }, format: :json

        expect(response).to_not be_success
      end

      it "raises an error when logged in" do
        moderator = log_in(:moderator)
        session[SessionController::ACTIVATE_USER_KEY] = moderator.id

        put :update_activation_email, params: {
          email: 'updatedemail@example.com'
        }, format: :json

        expect(response).to_not be_success
      end

      it "raises an error when the new email is taken" do
        active_user = Fabricate(:user)
        user = Fabricate(:inactive_user)
        session[SessionController::ACTIVATE_USER_KEY] = user.id

        put :update_activation_email, params: {
          email: active_user.email
        }, format: :json

        expect(response).to_not be_success
      end

      it "raises an error when the email is blacklisted" do
        user = Fabricate(:inactive_user)
        SiteSetting.email_domains_blacklist = 'example.com'
        session[SessionController::ACTIVATE_USER_KEY] = user.id
        put :update_activation_email, params: { email: 'test@example.com' }, format: :json
        expect(response).to_not be_success
      end

      it "can be updated" do
        user = Fabricate(:inactive_user)
        token = user.email_tokens.first

        session[SessionController::ACTIVATE_USER_KEY] = user.id

        put :update_activation_email, params: {
          email: 'updatedemail@example.com'
        }, format: :json

        expect(response).to be_success

        user.reload
        expect(user.email).to eq('updatedemail@example.com')
        expect(user.email_tokens.where(email: 'updatedemail@example.com', expired: false)).to be_present

        token.reload
        expect(token.expired?).to eq(true)
      end
    end

    context "with a username and password" do
      it "raises an error with an invalid username" do
        put :update_activation_email, params: {
          username: 'eviltrout',
          password: 'invalid-password',
          email: 'updatedemail@example.com'
        }, format: :json

        expect(response).to_not be_success
      end

      it "raises an error with an invalid password" do
        put :update_activation_email, params: {
          username: Fabricate(:inactive_user).username,
          password: 'invalid-password',
          email: 'updatedemail@example.com'
        }, format: :json

        expect(response).to_not be_success
      end

      it "raises an error for an active user" do
        put :update_activation_email, params: {
          username: Fabricate(:walter_white).username,
          password: 'letscook',
          email: 'updatedemail@example.com'
        }, format: :json

        expect(response).to_not be_success
      end

      it "raises an error when logged in" do
        log_in(:moderator)

        put :update_activation_email, params: {
          username: Fabricate(:inactive_user).username,
          password: 'qwerqwer123',
          email: 'updatedemail@example.com'
        }, format: :json

        expect(response).to_not be_success
      end

      it "raises an error when the new email is taken" do
        user = Fabricate(:user)

        put :update_activation_email, params: {
          username: Fabricate(:inactive_user).username,
          password: 'qwerqwer123',
          email: user.email
        }, format: :json

        expect(response).to_not be_success
      end

      it "can be updated" do
        user = Fabricate(:inactive_user)
        token = user.email_tokens.first

        put :update_activation_email, params: {
          username: user.username,
          password: 'qwerqwer123',
          email: 'updatedemail@example.com'
        }, format: :json

        expect(response).to be_success

        user.reload
        expect(user.email).to eq('updatedemail@example.com')
        expect(user.email_tokens.where(email: 'updatedemail@example.com', expired: false)).to be_present

        token.reload
        expect(token.expired?).to eq(true)
      end
    end
  end
end
