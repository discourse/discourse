require 'spec_helper'

describe SessionController do

  describe '.sso_login' do

    before do
      @sso_url = "http://somesite.com/discourse_sso"
      @sso_secret = "shjkfdhsfkjh"

      SiteSetting.stubs("enable_sso").returns(true)
      SiteSetting.stubs("sso_url").returns(@sso_url)
      SiteSetting.stubs("sso_secret").returns(@sso_secret)

      # We have 2 options, either fabricate an admin or don't
      # send welcome messages
      Fabricate(:admin)
      # skip for now
      # SiteSetting.stubs("send_welcome_message").returns(false)
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

      get :sso_login, Rack::Utils.parse_query(sso.payload)

      response.should redirect_to('/')
      logged_on_user = Discourse.current_user_provider.new(request.env).current_user
      logged_on_user.email.should == user.email
      logged_on_user.single_sign_on_record.external_id.should == "abc"
      logged_on_user.single_sign_on_record.external_username.should == 'sam'
    end

    it 'allows you to create an account' do
      sso = get_sso('/a/')
      sso.external_id = '666' # the number of the beast
      sso.email = 'bob@bob.com'
      sso.name = 'Sam Saffron'
      sso.username = 'sam'
      sso.custom_fields["shop_url"] = "http://my_shop.com"
      sso.custom_fields["shop_name"] = "Sam"

      get :sso_login, Rack::Utils.parse_query(sso.payload)
      response.should redirect_to('/a/')

      logged_on_user = Discourse.current_user_provider.new(request.env).current_user

      # ensure nothing is transient
      logged_on_user = User.find(logged_on_user.id)

      logged_on_user.email.should == 'bob@bob.com'
      logged_on_user.name.should == 'Sam Saffron'
      logged_on_user.username.should == 'sam'

      logged_on_user.single_sign_on_record.external_id.should == "666"
      logged_on_user.single_sign_on_record.external_username.should == 'sam'
      logged_on_user.active.should == true
      logged_on_user.custom_fields["shop_url"].should == "http://my_shop.com"
      logged_on_user.custom_fields["shop_name"].should == "Sam"
      logged_on_user.custom_fields["bla"].should == nil
    end

    it 'allows login to existing account with valid nonce' do
      sso = get_sso('/hello/world')
      sso.external_id = '997'

      user = Fabricate(:user)
      user.create_single_sign_on_record(external_id: '997', last_payload: '')

      get :sso_login, Rack::Utils.parse_query(sso.payload)

      user.single_sign_on_record.reload
      user.single_sign_on_record.last_payload.should == sso.unsigned_payload

      response.should redirect_to('/hello/world')
      logged_on_user = Discourse.current_user_provider.new(request.env).current_user

      user.id.should == logged_on_user.id

      # nonce is bad now
      get :sso_login, Rack::Utils.parse_query(sso.payload)
      response.code.should == '500'
    end

    describe 'local attribute override from SSO payload' do
      before do
        SiteSetting.stubs("sso_overrides_email").returns(true)
        SiteSetting.stubs("sso_overrides_username").returns(true)
        SiteSetting.stubs("sso_overrides_name").returns(true)

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
        get :sso_login, Rack::Utils.parse_query(@sso.payload)
        @user.single_sign_on_record.reload
        @user.single_sign_on_record.external_username.should == @sso.username
        @user.single_sign_on_record.external_email.should == @sso.email
        @user.single_sign_on_record.external_name.should == @sso.name
      end

      it 'overrides attributes' do
        get :sso_login, Rack::Utils.parse_query(@sso.payload)

        logged_on_user = Discourse.current_user_provider.new(request.env).current_user
        logged_on_user.username.should == @suggested_username
        logged_on_user.email.should == "#{@reversed_username}@garbage.org"
        logged_on_user.name.should == @suggested_name
      end

      it 'does not change matching attributes for an existing account' do
        @sso.username = @user.username
        @sso.name = @user.name
        @sso.email = @user.email

        get :sso_login, Rack::Utils.parse_query(@sso.payload)

        logged_on_user = Discourse.current_user_provider.new(request.env).current_user
        logged_on_user.username.should == @user.username
        logged_on_user.name.should == @user.name
        logged_on_user.email.should == @user.email
      end

      it 'does not change attributes for unchanged external attributes' do
        @user.single_sign_on_record.external_username = @sso.username
        @user.single_sign_on_record.external_email = @sso.email
        @user.single_sign_on_record.external_name = @sso.name
        @user.single_sign_on_record.save

        get :sso_login, Rack::Utils.parse_query(@sso.payload)
        logged_on_user = Discourse.current_user_provider.new(request.env).current_user
        logged_on_user.username.should == @user.username
        logged_on_user.email.should == @user.email
        logged_on_user.name.should == @user.name
      end
    end
  end

  describe '.create' do

    let(:user) { Fabricate(:user) }

    context 'when email is confirmed' do
      before do
        token = user.email_tokens.find_by(email: user.email)
        EmailToken.confirm(token.token)
      end

      it "raises an error when the login isn't present" do
        lambda { xhr :post, :create }.should raise_error(ActionController::ParameterMissing)
      end

      describe 'invalid password' do
        it "should return an error with an invalid password" do
          xhr :post, :create, login: user.username, password: 'sssss'
          ::JSON.parse(response.body)['error'].should be_present
        end
      end

      describe 'suspended user' do
        it 'should return an error' do
          User.any_instance.stubs(:suspended?).returns(true)
          User.any_instance.stubs(:suspended_till).returns(2.days.from_now)
          xhr :post, :create, login: user.username, password: 'myawesomepassword'
          ::JSON.parse(response.body)['error'].should be_present
        end
      end

      describe 'deactivated user' do
        it 'should return an error' do
          User.any_instance.stubs(:active).returns(false)
          xhr :post, :create, login: user.username, password: 'myawesomepassword'
          expect(JSON.parse(response.body)['error']).to eq(I18n.t('login.not_activated'))
        end
      end

      describe 'success by username' do
        it 'logs in correctly' do
          xhr :post, :create, login: user.username, password: 'myawesomepassword'

          user.reload

          session[:current_user_id].should == user.id
          user.auth_token.should be_present
          cookies[:_t].should == user.auth_token
        end
      end

      describe 'local logins disabled' do
        it 'fails' do
          SiteSetting.stubs(:enable_local_logins).returns(false)
          xhr :post, :create, login: user.username, password: 'myawesomepassword'
          response.status.to_i.should == 500
        end
      end

      describe 'strips leading @ symbol' do
        before do
          xhr :post, :create, login: "@" + user.username, password: 'myawesomepassword'
          user.reload
        end

        it 'sets a session id' do
          session[:current_user_id].should == user.id
        end
      end

      describe 'also allow login by email' do
        before do
          xhr :post, :create, login: user.email, password: 'myawesomepassword'
        end

        it 'sets a session id' do
          session[:current_user_id].should == user.id
        end
      end

      context 'login has leading and trailing space' do
        let(:username) { " #{user.username} " }
        let(:email) { " #{user.email} " }

        it "strips spaces from the username" do
          xhr :post, :create, login: username, password: 'myawesomepassword'
          ::JSON.parse(response.body)['error'].should_not be_present
        end

        it "strips spaces from the email" do
          xhr :post, :create, login: email, password: 'myawesomepassword'
          ::JSON.parse(response.body)['error'].should_not be_present
        end
      end

      describe "when the site requires approval of users" do
        before do
          SiteSetting.expects(:must_approve_users?).returns(true)
        end

        context 'with an unapproved user' do
          before do
            xhr :post, :create, login: user.email, password: 'myawesomepassword'
          end

          it "doesn't log in the user" do
            session[:current_user_id].should be_blank
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
            xhr :post, :create, login: user.email, password: 'myawesomepassword'
          end

          it 'sets a session id' do
            session[:current_user_id].should == user.id
          end
        end
      end
    end

    context 'when email has not been confirmed' do
      def post_login
        xhr :post, :create, login: user.email, password: 'myawesomepassword'
      end

      it "doesn't log in the user" do
        post_login
        session[:current_user_id].should be_blank
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
  end

  describe '.destroy' do
    before do
      @user = log_in
      xhr :delete, :destroy, id: @user.username
    end

    it 'removes the session variable' do
      session[:current_user_id].should be_blank
    end


    it 'removes the auth token cookie' do
      cookies[:_t].should be_blank
    end
  end

  describe '.forgot_password' do

    it 'raises an error without a username parameter' do
      lambda { xhr :post, :forgot_password }.should raise_error(ActionController::ParameterMissing)
    end

    context 'for a non existant username' do
      it "doesn't generate a new token for a made up username" do
        lambda { xhr :post, :forgot_password, login: 'made_up'}.should_not change(EmailToken, :count)
      end

      it "doesn't enqueue an email" do
        Jobs.expects(:enqueue).with(:user_mail, anything).never
        xhr :post, :forgot_password, login: 'made_up'
      end
    end

    context 'for an existing username' do
      let(:user) { Fabricate(:user) }

      it "returns a 500 if local logins are disabled" do
        SiteSetting.stubs(:enable_local_logins).returns(false)
        xhr :post, :forgot_password, login: user.username
        response.code.to_i.should == 500
      end

      it "generates a new token for a made up username" do
        lambda { xhr :post, :forgot_password, login: user.username}.should change(EmailToken, :count)
      end

      it "enqueues an email" do
        Jobs.expects(:enqueue).with(:user_email, has_entries(type: :forgot_password, user_id: user.id))
        xhr :post, :forgot_password, login: user.username
      end
    end

  end

  describe '.current' do
    context "when not logged in" do
      it "retuns 404" do
        xhr :get, :current
        response.should_not be_success
      end
    end

    context "when logged in" do
      let!(:user) { log_in }

      it "returns the JSON for the user" do
        xhr :get, :current
        response.should be_success
        json = ::JSON.parse(response.body)
        json['current_user'].should be_present
        json['current_user']['id'].should == user.id
      end
    end
  end
end
