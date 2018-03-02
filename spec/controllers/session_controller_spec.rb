require 'rails_helper'

describe SessionController do
  shared_examples 'failed to continue local login' do
    it 'should return the right response' do
      expect(response).not_to be_success
      expect(response.status.to_i).to eq 500
    end
  end

  describe '#become' do
    let!(:user) { Fabricate(:user) }

    it "does not work when not in development mode" do
      Rails.env.stubs(:development?).returns(false)
      get :become, params: { session_id: user.username }, format: :json
      expect(response).not_to be_redirect
      expect(session[:current_user_id]).to be_blank
    end

    it "works in developmenet mode" do
      Rails.env.stubs(:development?).returns(true)
      get :become, params: { session_id: user.username }, format: :json
      expect(response).to be_redirect
      expect(session[:current_user_id]).to eq(user.id)
    end
  end

  describe '#sso_login' do

    before do
      @sso_url = "http://somesite.com/discourse_sso"
      @sso_secret = "shjkfdhsfkjh"

      request.host = Discourse.current_hostname

      SiteSetting.sso_url = @sso_url
      SiteSetting.enable_sso = true
      SiteSetting.sso_secret = @sso_secret

      # We have 2 options, either fabricate an admin or don't
      # send welcome messages
      Fabricate(:admin)
      # skip for now
      # SiteSetting.send_welcome_message = false
    end

    def get_sso(return_path)
      nonce = SecureRandom.hex
      dso = DiscourseSingleSignOn.new
      dso.nonce = nonce
      dso.register_nonce(return_path)

      sso = SingleSignOn.new
      sso.nonce = nonce
      sso.sso_secret = @sso_secret
      sso
    end

    it 'can take over an account' do
      sso = get_sso("/")
      user = Fabricate(:user)
      sso.email = user.email
      sso.external_id = 'abc'
      sso.username = 'sam'

      get :sso_login, params: Rack::Utils.parse_query(sso.payload)

      expect(response).to redirect_to('/')
      logged_on_user = Discourse.current_user_provider.new(request.env).current_user
      expect(logged_on_user.email).to eq(user.email)
      expect(logged_on_user.single_sign_on_record.external_id).to eq("abc")
      expect(logged_on_user.single_sign_on_record.external_username).to eq('sam')
    end

    def sso_for_ip_specs
      sso = get_sso('/a/')
      sso.external_id = '666' # the number of the beast
      sso.email = 'bob@bob.com'
      sso.name = 'Sam Saffron'
      sso.username = 'sam'
      sso
    end

    it 'respects IP restrictions on create' do
      screened_ip = Fabricate(:screened_ip_address)
      ActionDispatch::Request.any_instance.stubs(:remote_ip).returns(screened_ip.ip_address)

      sso = sso_for_ip_specs
      get :sso_login, params: Rack::Utils.parse_query(sso.payload)

      logged_on_user = Discourse.current_user_provider.new(request.env).current_user
      expect(logged_on_user).to eq(nil)
    end

    it 'respects IP restrictions on login' do
      sso = sso_for_ip_specs
      _user = DiscourseSingleSignOn.parse(sso.payload).lookup_or_create_user(request.remote_ip)

      sso = sso_for_ip_specs
      screened_ip = Fabricate(:screened_ip_address)
      ActionDispatch::Request.any_instance.stubs(:remote_ip).returns(screened_ip.ip_address)

      get :sso_login, params: Rack::Utils.parse_query(sso.payload)
      logged_on_user = Discourse.current_user_provider.new(request.env).current_user
      expect(logged_on_user).to be_blank
    end

    it 'respects email restrictions' do
      sso = get_sso('/a/')
      sso.external_id = '666' # the number of the beast
      sso.email = 'bob@bob.com'
      sso.name = 'Sam Saffron'
      sso.username = 'sam'

      ScreenedEmail.block('bob@bob.com')
      get :sso_login, params: Rack::Utils.parse_query(sso.payload)

      logged_on_user = Discourse.current_user_provider.new(request.env).current_user
      expect(logged_on_user).to eq(nil)
    end

    it 'allows you to create an admin account' do
      sso = get_sso('/a/')
      sso.external_id = '666' # the number of the beast
      sso.email = 'bob@bob.com'
      sso.name = 'Sam Saffron'
      sso.username = 'sam'
      sso.custom_fields["shop_url"] = "http://my_shop.com"
      sso.custom_fields["shop_name"] = "Sam"
      sso.admin = true

      get :sso_login, params: Rack::Utils.parse_query(sso.payload)

      logged_on_user = Discourse.current_user_provider.new(request.env).current_user
      expect(logged_on_user.admin).to eq(true)
    end

    it 'redirects to a non-relative url' do
      sso = get_sso("#{Discourse.base_url}/b/")
      sso.external_id = '666' # the number of the beast
      sso.email = 'bob@bob.com'
      sso.name = 'Sam Saffron'
      sso.username = 'sam'

      get :sso_login, params: Rack::Utils.parse_query(sso.payload)
      expect(response).to redirect_to('/b/')
    end

    it 'redirects to random url if it is allowed' do
      SiteSetting.sso_allows_all_return_paths = true

      sso = get_sso('https://gusundtrout.com')
      sso.external_id = '666' # the number of the beast
      sso.email = 'bob@bob.com'
      sso.name = 'Sam Saffron'
      sso.username = 'sam'

      get :sso_login, params: Rack::Utils.parse_query(sso.payload)
      expect(response).to redirect_to('https://gusundtrout.com')
    end

    it 'redirects to root if the host of the return_path is different' do
      sso = get_sso('//eviltrout.com')
      sso.external_id = '666' # the number of the beast
      sso.email = 'bob@bob.com'
      sso.name = 'Sam Saffron'
      sso.username = 'sam'

      get :sso_login, params: Rack::Utils.parse_query(sso.payload)
      expect(response).to redirect_to('/')
    end

    it 'redirects to root if the host of the return_path is different' do
      sso = get_sso('http://eviltrout.com')
      sso.external_id = '666' # the number of the beast
      sso.email = 'bob@bob.com'
      sso.name = 'Sam Saffron'
      sso.username = 'sam'

      get :sso_login, params: Rack::Utils.parse_query(sso.payload)
      expect(response).to redirect_to('/')
    end

    it 'allows you to create an account' do
      sso = get_sso('/a/')
      sso.external_id = '666' # the number of the beast
      sso.email = 'bob@bob.com'
      sso.name = 'Sam Saffron'
      sso.username = 'sam'
      sso.custom_fields["shop_url"] = "http://my_shop.com"
      sso.custom_fields["shop_name"] = "Sam"

      events = DiscourseEvent.track_events do
        get :sso_login, params: Rack::Utils.parse_query(sso.payload)
      end

      expect(events.map { |event| event[:event_name] }).to include(
       :user_logged_in, :user_first_logged_in
      )

      expect(response).to redirect_to('/a/')

      logged_on_user = Discourse.current_user_provider.new(request.env).current_user

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

    context 'when sso emails are not trusted' do
      context 'if you have not activated your account' do
        it 'does not log you in' do
          sso = get_sso('/a/')
          sso.external_id = '666' # the number of the beast
          sso.email = 'bob@bob.com'
          sso.name = 'Sam Saffron'
          sso.username = 'sam'
          sso.require_activation = true

          get :sso_login, params: Rack::Utils.parse_query(sso.payload)

          logged_on_user = Discourse.current_user_provider.new(request.env).current_user
          expect(logged_on_user).to eq(nil)
        end

        it 'sends an activation email' do
          Jobs.expects(:enqueue).with(:critical_user_email, has_entries(type: :signup))
          sso = get_sso('/a/')
          sso.external_id = '666' # the number of the beast
          sso.email = 'bob@bob.com'
          sso.name = 'Sam Saffron'
          sso.username = 'sam'
          sso.require_activation = true

          get :sso_login, params: Rack::Utils.parse_query(sso.payload)
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

          get :sso_login, params: Rack::Utils.parse_query(sso.payload)

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

      get :sso_login, params: Rack::Utils.parse_query(sso.payload)

      user.single_sign_on_record.reload
      expect(user.single_sign_on_record.last_payload).to eq(sso.unsigned_payload)

      expect(response).to redirect_to('/hello/world')
      logged_on_user = Discourse.current_user_provider.new(request.env).current_user

      expect(user.id).to eq(logged_on_user.id)

      # nonce is bad now
      get :sso_login, params: Rack::Utils.parse_query(sso.payload)
      expect(response.code).to eq('419')
    end

    describe 'can act as an SSO provider' do
      before do
        SiteSetting.enable_sso_provider = true
        SiteSetting.enable_sso = false
        SiteSetting.enable_local_logins = true
        SiteSetting.sso_secret = "topsecret"

        @sso = SingleSignOn.new
        @sso.nonce = "mynonce"
        @sso.sso_secret = SiteSetting.sso_secret
        @sso.return_sso_url = "http://somewhere.over.rainbow/sso"

        @user = Fabricate(:user, password: "myfrogs123ADMIN", active: true, admin: true)
        group = Fabricate(:group)
        group.add(@user)
        @user.reload
        EmailToken.update_all(confirmed: true)
      end

      it "successfully logs in and redirects user to return_sso_url when the user is not logged in" do
        get :sso_provider, params: Rack::Utils.parse_query(@sso.payload)
        expect(response).to redirect_to("/login")

        post :create,
          params: { login: @user.username, password: "myfrogs123ADMIN" },
          format: :json,
          xhr: true

        location = response.cookies["sso_destination_url"]
        # javascript code will handle redirection of user to return_sso_url
        expect(location).to match(/^http:\/\/somewhere.over.rainbow\/sso/)

        payload = location.split("?")[1]
        sso2 = SingleSignOn.parse(payload, "topsecret")

        expect(sso2.email).to eq(@user.email)
        expect(sso2.name).to eq(@user.name)
        expect(sso2.username).to eq(@user.username)
        expect(sso2.external_id).to eq(@user.id.to_s)
        expect(sso2.admin).to eq(true)
        expect(sso2.moderator).to eq(false)
        expect(sso2.groups).to eq(@user.groups.pluck(:name))
      end

      it "successfully redirects user to return_sso_url when the user is logged in" do
        log_in_user(@user)

        get :sso_provider, params: Rack::Utils.parse_query(@sso.payload)

        location = response.header["Location"]
        expect(location).to match(/^http:\/\/somewhere.over.rainbow\/sso/)

        payload = location.split("?")[1]
        sso2 = SingleSignOn.parse(payload, "topsecret")

        expect(sso2.email).to eq(@user.email)
        expect(sso2.name).to eq(@user.name)
        expect(sso2.username).to eq(@user.username)
        expect(sso2.external_id).to eq(@user.id.to_s)
        expect(sso2.admin).to eq(true)
        expect(sso2.moderator).to eq(false)
      end
    end

    describe 'local attribute override from SSO payload' do
      before do
        SiteSetting.email_editable = false
        SiteSetting.sso_overrides_email = true
        SiteSetting.sso_overrides_username = true
        SiteSetting.sso_overrides_name = true

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
        get :sso_login, params: Rack::Utils.parse_query(@sso.payload)
        @user.single_sign_on_record.reload
        expect(@user.single_sign_on_record.external_username).to eq(@sso.username)
        expect(@user.single_sign_on_record.external_email).to eq(@sso.email)
        expect(@user.single_sign_on_record.external_name).to eq(@sso.name)
      end

      it 'overrides attributes' do
        get :sso_login, params: Rack::Utils.parse_query(@sso.payload)

        logged_on_user = Discourse.current_user_provider.new(request.env).current_user
        expect(logged_on_user.username).to eq(@suggested_username)
        expect(logged_on_user.email).to eq("#{@reversed_username}@garbage.org")
        expect(logged_on_user.name).to eq(@sso.name)
      end

      it 'does not change matching attributes for an existing account' do
        @sso.username = @user.username
        @sso.name = @user.name
        @sso.email = @user.email

        get :sso_login, params: Rack::Utils.parse_query(@sso.payload)

        logged_on_user = Discourse.current_user_provider.new(request.env).current_user
        expect(logged_on_user.username).to eq(@user.username)
        expect(logged_on_user.name).to eq(@user.name)
        expect(logged_on_user.email).to eq(@user.email)
      end

    end
  end

  describe '#sso_provider' do
    before do
      SiteSetting.enable_sso_provider = true
      SiteSetting.enable_sso = false
      SiteSetting.enable_local_logins = true
      SiteSetting.sso_secret = "topsecret"

      @sso = SingleSignOn.new
      @sso.nonce = "mynonce"
      @sso.sso_secret = SiteSetting.sso_secret
      @sso.return_sso_url = "http://somewhere.over.rainbow/sso"

      @user = Fabricate(:user, password: "myfrogs123ADMIN", active: true, admin: true)
      EmailToken.update_all(confirmed: true)
    end

    it "successfully logs in and redirects user to return_sso_url when the user is not logged in" do
      get :sso_provider, params: Rack::Utils.parse_query(@sso.payload)
      expect(response).to redirect_to("/login")

      post :create,
        params: { login: @user.username, password: "myfrogs123ADMIN" },
        format: :json,
        xhr: true

      location = response.cookies["sso_destination_url"]
      # javascript code will handle redirection of user to return_sso_url
      expect(location).to match(/^http:\/\/somewhere.over.rainbow\/sso/)

      payload = location.split("?")[1]
      sso2 = SingleSignOn.parse(payload, "topsecret")

      expect(sso2.email).to eq(@user.email)
      expect(sso2.name).to eq(@user.name)
      expect(sso2.username).to eq(@user.username)
      expect(sso2.external_id).to eq(@user.id.to_s)
      expect(sso2.admin).to eq(true)
      expect(sso2.moderator).to eq(false)
    end

    it "successfully redirects user to return_sso_url when the user is logged in" do
      log_in_user(@user)

      get :sso_provider, params: Rack::Utils.parse_query(@sso.payload)

      location = response.header["Location"]
      expect(location).to match(/^http:\/\/somewhere.over.rainbow\/sso/)

      payload = location.split("?")[1]
      sso2 = SingleSignOn.parse(payload, "topsecret")

      expect(sso2.email).to eq(@user.email)
      expect(sso2.name).to eq(@user.name)
      expect(sso2.username).to eq(@user.username)
      expect(sso2.external_id).to eq(@user.id.to_s)
      expect(sso2.admin).to eq(true)
      expect(sso2.moderator).to eq(false)
    end
  end

  describe '#create' do

    let(:user) { Fabricate(:user) }

    context 'local login is disabled' do
      before do
        SiteSetting.enable_local_logins = false

        post :create, params: {
          login: user.username, password: 'myawesomepassword'
        }, format: :json
      end
      it_behaves_like "failed to continue local login"
    end

    context 'SSO is enabled' do
      before do
        SiteSetting.sso_url = "https://www.example.com/sso"
        SiteSetting.enable_sso = true

        post :create, params: {
          login: user.username, password: 'myawesomepassword'
        }, format: :json
      end
      it_behaves_like "failed to continue local login"
    end

    context 'when email is confirmed' do
      before do
        token = user.email_tokens.find_by(email: user.email)
        EmailToken.confirm(token.token)
      end

      it "raises an error when the login isn't present" do
        expect do
          post :create, format: :json
        end.to raise_error(ActionController::ParameterMissing)
      end

      describe 'invalid password' do
        it "should return an error with an invalid password" do
          post :create, params: {
            login: user.username, password: 'sssss'
          }, format: :json

          expect(::JSON.parse(response.body)['error']).to eq(
            I18n.t("login.incorrect_username_email_or_password")
          )
        end
      end

      describe 'invalid password' do
        it "should return an error with an invalid password if too long" do
          User.any_instance.expects(:confirm_password?).never
          post :create, params: {
            login: user.username, password: ('s' * (User.max_password_length + 1))
          }, format: :json

          expect(::JSON.parse(response.body)['error']).to eq(
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

          post :create, params: {
            login: user.username, password: 'myawesomepassword'
          }, format: :json

          expect(JSON.parse(response.body)['error']).to eq(I18n.t('login.suspended_with_reason',
            date: I18n.l(user.suspended_till, format: :date_only),
            reason: Rack::Utils.escape_html(user.suspend_reason)
          ))
        end
      end

      describe 'deactivated user' do
        it 'should return an error' do
          User.any_instance.stubs(:active).returns(false)

          post :create, params: {
            login: user.username, password: 'myawesomepassword'
          }, format: :json

          expect(JSON.parse(response.body)['error']).to eq(I18n.t('login.not_activated'))
        end
      end

      describe 'success by username' do
        it 'logs in correctly' do
          events = DiscourseEvent.track_events do
            post :create, params: {
              login: user.username, password: 'myawesomepassword'
            }, format: :json
          end

          expect(events.map { |event| event[:event_name] }).to include(
            :user_logged_in, :user_first_logged_in
          )

          user.reload

          expect(session[:current_user_id]).to eq(user.id)
          expect(user.user_auth_tokens.count).to eq(1)
          expect(UserAuthToken.hash_token(cookies[:_t])).to eq(user.user_auth_tokens.first.auth_token)
        end
      end

      context 'when user has 2-factor logins' do
        let!(:user_second_factor) { Fabricate(:user_second_factor, user: user) }

        describe 'when second factor token is missing' do
          it 'should return the right response' do
            post :create, params: {
              login: user.username,
              password: 'myawesomepassword',
            }, format: :json

            expect(JSON.parse(response.body)['error']).to eq(I18n.t(
              'login.invalid_second_factor_code'
            ))
          end
        end

        describe 'when second factor token is invalid' do
          it 'should return the right response' do
            post :create, params: {
              login: user.username,
              password: 'myawesomepassword',
              second_factor_token: '00000000'
            }, format: :json

            expect(JSON.parse(response.body)['error']).to eq(I18n.t(
              'login.invalid_second_factor_code'
            ))
          end
        end

        describe 'when second factor token is valid' do
          it 'should log the user in' do
            post :create, params: {
              login: user.username,
              password: 'myawesomepassword',
              second_factor_token: ROTP::TOTP.new(user_second_factor.data).now
            }, format: :json

            user.reload

            expect(session[:current_user_id]).to eq(user.id)
            expect(user.user_auth_tokens.count).to eq(1)

            expect(UserAuthToken.hash_token(cookies[:_t]))
              .to eq(user.user_auth_tokens.first.auth_token)
          end
        end
      end

      describe 'with a blocked IP' do
        before do
          screened_ip = Fabricate(:screened_ip_address)
          ActionDispatch::Request.any_instance.stubs(:remote_ip).returns(screened_ip.ip_address)
          post :create, params: {
            login: "@" + user.username, password: 'myawesomepassword'
          }, format: :json

          user.reload
        end

        it "doesn't log in" do
          expect(session[:current_user_id]).to be_nil
        end
      end

      describe 'strips leading @ symbol' do
        before do
          post :create, params: {
            login: "@" + user.username, password: 'myawesomepassword'
          }, format: :json

          user.reload
        end

        it 'sets a session id' do
          expect(session[:current_user_id]).to eq(user.id)
        end
      end

      describe 'also allow login by email' do
        before do
          post :create, params: {
            login: user.email, password: 'myawesomepassword'
          }, format: :json
        end

        it 'sets a session id' do
          expect(session[:current_user_id]).to eq(user.id)
        end
      end

      context 'login has leading and trailing space' do
        let(:username) { " #{user.username} " }
        let(:email) { " #{user.email} " }

        it "strips spaces from the username" do
          post :create, params: {
            login: username, password: 'myawesomepassword'
          }, format: :json

          expect(::JSON.parse(response.body)['error']).not_to be_present
        end

        it "strips spaces from the email" do
          post :create, params: {
            login: email, password: 'myawesomepassword'
          }, format: :json

          expect(::JSON.parse(response.body)['error']).not_to be_present
        end
      end

      describe "when the site requires approval of users" do
        before do
          SiteSetting.expects(:must_approve_users?).returns(true)
        end

        context 'with an unapproved user' do
          before do
            post :create, params: {
              login: user.email, password: 'myawesomepassword'
            }, format: :json
          end

          it "doesn't log in the user" do
            expect(session[:current_user_id]).to be_blank
          end

          it "shows the 'not approved' error message" do
            expect(JSON.parse(response.body)['error']).to eq(
              I18n.t('login.not_approved')
            )
          end
        end

        context "with an unapproved user who is an admin" do
          before do
            User.any_instance.stubs(:admin?).returns(true)

            post :create, params: {
              login: user.email, password: 'myawesomepassword'
            }, format: :json
          end

          it 'sets a session id' do
            expect(session[:current_user_id]).to eq(user.id)
          end
        end
      end

      context 'when admins are restricted by ip address' do
        let(:permitted_ip_address) { '111.234.23.11' }
        before do
          Fabricate(:screened_ip_address, ip_address: permitted_ip_address, action_type: ScreenedIpAddress.actions[:allow_admin])
          SiteSetting.use_admin_ip_whitelist = true
        end

        it 'is successful for admin at the ip address' do
          User.any_instance.stubs(:admin?).returns(true)
          ActionDispatch::Request.any_instance.stubs(:remote_ip).returns(permitted_ip_address)

          post :create, params: {
            login: user.username, password: 'myawesomepassword'
          }, format: :json

          expect(session[:current_user_id]).to eq(user.id)
        end

        it 'returns an error for admin not at the ip address' do
          User.any_instance.stubs(:admin?).returns(true)
          ActionDispatch::Request.any_instance.stubs(:remote_ip).returns("111.234.23.12")

          post :create, params: {
            login: user.username, password: 'myawesomepassword'
          }, format: :json

          expect(JSON.parse(response.body)['error']).to be_present
          expect(session[:current_user_id]).not_to eq(user.id)
        end

        it 'is successful for non-admin not at the ip address' do
          User.any_instance.stubs(:admin?).returns(false)
          ActionDispatch::Request.any_instance.stubs(:remote_ip).returns("111.234.23.12")

          post :create, params: {
            login: user.username, password: 'myawesomepassword'
          }, format: :json

          expect(session[:current_user_id]).to eq(user.id)
        end
      end
    end

    context 'when email has not been confirmed' do
      def post_login
        post :create, params: {
          login: user.email, password: 'myawesomepassword'
        }, format: :json
      end

      it "doesn't log in the user" do
        post_login
        expect(session[:current_user_id]).to be_blank
      end

      it "shows the 'not activated' error message" do
        post_login
        expect(JSON.parse(response.body)['error']).to eq(
          I18n.t 'login.not_activated'
        )
      end

      context "and the 'must approve users' site setting is enabled" do
        before { SiteSetting.expects(:must_approve_users?).returns(true) }

        it "shows the 'not approved' error message" do
          post_login
          expect(JSON.parse(response.body)['error']).to eq(
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
          post :create, params: {
            login: user.username, password: 'myawesomepassword'
          }, format: :json

          expect(response).to be_success
        end

        post :create, params: {
          login: user.username, password: 'myawesomepassword'
        }, format: :json

        expect(response.status).to eq(429)
        json = JSON.parse(response.body)
        expect(json["error_type"]).to eq("rate_limit")
      end

      it 'rate limits second factor attempts' do
        RateLimiter.enable
        RateLimiter.clear_all!

        3.times do
          post :create, params: {
            login: user.username,
            password: 'myawesomepassword',
            second_factor_token: '000000'
          }, format: :json

          expect(response).to be_success
        end

        post :create, params: {
          login: user.username,
          password: 'myawesomepassword',
          second_factor_token: '000000'
        }, format: :json

        expect(response.status).to eq(429)
        json = JSON.parse(response.body)
        expect(json["error_type"]).to eq("rate_limit")
      end
    end
  end

  describe '.destroy' do
    before do
      @user = log_in
      delete :destroy, params: { id: @user.username }, format: :json
    end

    it 'removes the session variable' do
      expect(session[:current_user_id]).to be_blank
    end

    it 'removes the auth token cookie' do
      expect(response.cookies["_t"]).to be_blank
    end
  end

  describe '.forgot_password' do

    it 'raises an error without a username parameter' do
      expect do
        post :forgot_password, format: :json
      end.to raise_error(ActionController::ParameterMissing)
    end

    context 'for a non existant username' do
      it "doesn't generate a new token for a made up username" do
        expect do
          post :forgot_password, params: { login: 'made_up' }, format: :json
        end.not_to change(EmailToken, :count)
      end

      it "doesn't enqueue an email" do
        Jobs.expects(:enqueue).with(:user_mail, anything).never
        post :forgot_password, params: { login: 'made_up' }, format: :json
      end
    end

    context 'for an existing username' do
      let(:user) { Fabricate(:user) }

      context 'local login is disabled' do
        before do
          SiteSetting.enable_local_logins = false
          post :forgot_password, params: { login: user.username }, format: :json
        end
        it_behaves_like "failed to continue local login"
      end

      context 'SSO is enabled' do
        before do
          SiteSetting.sso_url = "https://www.example.com/sso"
          SiteSetting.enable_sso = true

          post :create, params: {
            login: user.username, password: 'myawesomepassword'
          }, format: :json
        end
        it_behaves_like "failed to continue local login"
      end

      it "generates a new token for a made up username" do
        expect do
          post :forgot_password, params: { login: user.username }, format: :json
        end.to change(EmailToken, :count)
      end

      it "enqueues an email" do
        Jobs.expects(:enqueue).with(:critical_user_email, has_entries(type: :forgot_password, user_id: user.id))
        post :forgot_password, params: { login: user.username }, format: :json
      end
    end

    context 'do nothing to system username' do
      let(:system) { Discourse.system_user }

      it 'generates no token for system username' do
        expect do
          post :forgot_password, params: { login: system.username }, format: :json
        end.not_to change(EmailToken, :count)
      end

      it 'enqueues no email' do
        Jobs.expects(:enqueue).never
        post :forgot_password, params: { login: system.username }, format: :json
      end
    end

    context 'for a staged account' do
      let!(:staged) { Fabricate(:staged) }

      it 'generates no token for staged username' do
        expect do
          post :forgot_password, params: { login: staged.username }, format: :json
        end.not_to change(EmailToken, :count)
      end

      it 'enqueues no email' do
        Jobs.expects(:enqueue).never
        post :forgot_password, params: { login: staged.username }, format: :json
      end
    end
  end

  describe '#current' do
    context "when not logged in" do
      it "retuns 404" do
        get :current, format: :json
        expect(response).not_to be_success
      end
    end

    context "when logged in" do
      let!(:user) { log_in }

      it "returns the JSON for the user" do
        get :current, format: :json
        expect(response).to be_success
        json = ::JSON.parse(response.body)
        expect(json['current_user']).to be_present
        expect(json['current_user']['id']).to eq(user.id)
      end
    end
  end
end
