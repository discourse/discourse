require 'spec_helper'

describe UsersController do

  before do
    UsersController.any_instance.stubs(:honeypot_value).returns(nil)
    UsersController.any_instance.stubs(:challenge_value).returns(nil)
  end

  describe '.show' do
    let!(:user) { log_in }

    it 'returns success' do
      xhr :get, :show, username: user.username
      response.should be_success
    end

    it "returns not found when the username doesn't exist" do
      xhr :get, :show, username: 'madeuppity'
      response.should_not be_success
    end

    it "raises an error on invalid access" do
      Guardian.any_instance.expects(:can_see?).with(user).returns(false)
      xhr :get, :show, username: user.username
      response.should be_forbidden
    end

    context "fetching a user by external_id" do
      before { user.create_single_sign_on_record(external_id: '997', last_payload: '') }

      it "returns fetch for a matching external_id" do
        xhr :get, :show, external_id: '997'
        response.should be_success
      end

      it "returns not found when external_id doesn't match" do
        xhr :get, :show, external_id: '99'
        response.should_not be_success
      end
    end
  end

  describe '.user_preferences_redirect' do
    it 'requires the user to be logged in' do
      lambda { get :user_preferences_redirect }.should raise_error(Discourse::NotLoggedIn)
    end

    it "redirects to their profile when logged in" do
      user = log_in
      get :user_preferences_redirect
      response.should redirect_to("/users/#{user.username_lower}/preferences")
    end
  end

  describe '.authorize_email' do
    it 'errors out for invalid tokens' do
      get :authorize_email, token: 'asdfasdf'
      response.should be_success
      flash[:error].should be_present
    end

    context 'valid token' do

      it 'authorizes with a correct token' do
        user = Fabricate(:user)
        email_token = user.email_tokens.create(email: user.email)

        get :authorize_email, token: email_token.token
        response.should be_success
        flash[:error].should be_blank
        session[:current_user_id].should be_present
      end
    end
  end

  describe '.activate_account' do
    context 'invalid token' do
      before do
        EmailToken.expects(:confirm).with('asdfasdf').returns(nil)
        get :activate_account, token: 'asdfasdf'
      end

      it 'return success' do
        response.should be_success
      end

      it 'sets a flash error' do
        flash[:error].should be_present
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
          get :activate_account, token: 'asdfasdf'
        end

        it "doesn't enqueue the welcome message if the object returns false" do
          user.send_welcome_message = false
          user.expects(:enqueue_welcome_message).with('welcome_user').never
          get :activate_account, token: 'asdfasdf'
        end

      end

      context 'response' do
        before do
          Guardian.any_instance.expects(:can_access_forum?).returns(true)
          EmailToken.expects(:confirm).with('asdfasdf').returns(user)
          get :activate_account, token: 'asdfasdf'
        end

        it 'returns success' do
          response.should be_success
        end

        it "doesn't set an error" do
          flash[:error].should be_blank
        end

        it 'logs in as the user' do
          session[:current_user_id].should be_present
        end

        it "doesn't set @needs_approval" do
          assigns[:needs_approval].should be_blank
        end

      end

      context 'user is not approved' do
        before do
          Guardian.any_instance.expects(:can_access_forum?).returns(false)
          EmailToken.expects(:confirm).with('asdfasdf').returns(user)
          get :activate_account, token: 'asdfasdf'
        end

        it 'returns success' do
          response.should be_success
        end

        it 'sets @needs_approval' do
          assigns[:needs_approval].should be_present
        end

        it "doesn't set an error" do
          flash[:error].should be_blank
        end

        it "doesn't log the user in" do
          session[:current_user_id].should be_blank
        end
      end

    end
  end

  describe '.change_email' do
    let(:new_email) { 'bubblegum@adventuretime.ooo' }

    it "requires you to be logged in" do
      lambda { xhr :put, :change_email, username: 'asdf', email: new_email }.should raise_error(Discourse::NotLoggedIn)
    end

    context 'when logged in' do
      let!(:user) { log_in }

      it 'raises an error without an email parameter' do
        lambda { xhr :put, :change_email, username: user.username }.should raise_error(ActionController::ParameterMissing)
      end

      it "raises an error if you can't edit the user's email" do
        Guardian.any_instance.expects(:can_edit_email?).with(user).returns(false)
        xhr :put, :change_email, username: user.username, email: new_email
        response.should be_forbidden
      end

      context 'when the new email address is taken' do
        let!(:other_user) { Fabricate(:coding_horror) }
        it 'raises an error' do
          lambda { xhr :put, :change_email, username: user.username, email: other_user.email }.should raise_error(Discourse::InvalidParameters)
        end

        it 'raises an error if there is whitespace too' do
          lambda { xhr :put, :change_email, username: user.username, email: other_user.email + ' ' }.should raise_error(Discourse::InvalidParameters)
        end
      end

      context 'success' do

        it 'has an email token' do
          lambda { xhr :put, :change_email, username: user.username, email: new_email }.should change(EmailToken, :count)
        end

        it 'enqueues an email authorization' do
          Jobs.expects(:enqueue).with(:user_email, has_entries(type: :authorize_email, user_id: user.id, to_address: new_email))
          xhr :put, :change_email, username: user.username, email: new_email
        end
      end
    end

  end

  describe '.password_reset' do
    let(:user) { Fabricate(:user) }

    context "you can view it even if login is required" do
      it "returns success" do
        SiteSetting.login_required = true
        get :password_reset, token: 'asdfasdf'
        response.should be_success
      end
    end

    context 'invalid token' do
      before do
        get :password_reset, token: SecureRandom.hex
      end

      it 'disallows login' do
        flash[:error].should be_present
        session[:current_user_id].should be_blank
        response.should be_success
      end

    end

    context 'valid token' do
      it 'returns success' do
        user = Fabricate(:user)
        token = user.email_tokens.create(email: user.email).token

        get :password_reset, token: token
        put :password_reset, token: token, password: 'newpassword'
        response.should be_success
        flash[:error].should be_blank
      end
    end

    context 'submit change' do
      before do
        EmailToken.expects(:confirm).with('asdfasdf').returns(user)
      end

      it "logs in the user" do
        put :password_reset, token: 'asdfasdf', password: 'newpassword'
        session[:current_user_id].should be_present
      end

      it "doesn't log in the user when not approved" do
        SiteSetting.expects(:must_approve_users?).returns(true)
        put :password_reset, token: 'asdfasdf', password: 'newpassword'
        session[:current_user_id].should be_blank
      end
    end
  end

  describe '#create' do
    before do
      @user = Fabricate.build(:user)
      @user.password = "strongpassword"
      DiscourseHub.stubs(:register_username).returns([true, nil])
    end

    def post_user
      xhr :post, :create,
        name: @user.name,
        username: @user.username,
        password: "strongpassword",
        email: @user.email
    end

    context 'when creating a non active user (unconfirmed email)' do

      it 'returns a 500 when local logins are disabled' do
        SiteSetting.expects(:enable_local_logins).returns(false)
        post_user

        expect(response.status).to eq(500)
      end

      it 'creates a user correctly' do
        Jobs.expects(:enqueue).with(:user_email, has_entries(type: :signup))
        User.any_instance.expects(:enqueue_welcome_message).with('welcome_user').never

        post_user

        expect(JSON.parse(response.body)['active']).to be_false
      end

      context "and 'must approve users' site setting is enabled" do
        before { SiteSetting.expects(:must_approve_users).returns(true) }

        it 'does not enqueue an email' do
          Jobs.expects(:enqueue).never
          post_user
        end

        it 'does not login the user' do
          post_user
          expect(session[:current_user_id]).to be_blank
        end

        it 'indicates the user is not active in the response' do
          post_user
          expect(JSON.parse(response.body)['active']).to be_false
        end

        it "shows the 'waiting approval' message" do
          post_user
          expect(JSON.parse(response.body)['message']).to eq(
            I18n.t 'login.wait_approval'
          )
        end
      end
    end

    context 'when creating an active user (confirmed email)' do
      before { User.any_instance.stubs(:active?).returns(true) }

      it 'enqueues a welcome email' do
        User.any_instance.expects(:enqueue_welcome_message).with('welcome_user')
        post_user
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
        session[:current_user_id].should be_present
      end

      it 'indicates the user is active in the response' do
        User.any_instance.expects(:enqueue_welcome_message)
        post_user
        expect(JSON.parse(response.body)['active']).to be_true
      end

      context 'authentication records for' do

        before do
          SiteSetting.expects(:must_approve_users).returns(true)
        end

        it 'should create twitter user info if required' do
          SiteSetting.stubs(:enable_twitter_logins?).returns(true)
          twitter_auth = { twitter_user_id: 42, twitter_screen_name: "bruce" }
          auth = session[:authentication] = {}
          auth[:authenticator_name] = 'twitter'
          auth[:extra_data] = twitter_auth
          TwitterUserInfo.expects(:create)

          post_user
        end
      end
    end

    context 'after success' do
      before { post_user }

      it 'should succeed' do
        should respond_with(:success)
      end

      it 'has the proper JSON' do
        json = JSON::parse(response.body)
        json["success"].should be_true
      end

      it 'should not result in an active account' do
        User.find_by(username: @user.username).active.should be_false
      end
    end

    shared_examples 'honeypot fails' do
      it 'should not create a new user' do
        expect {
          xhr :post, :create, create_params
        }.to_not change { User.count }
      end

      it 'should not send an email' do
        User.any_instance.expects(:enqueue_welcome_message).never
        xhr :post, :create, create_params
      end

      it 'should say it was successful' do
        xhr :post, :create, create_params
        json = JSON::parse(response.body)
        json["success"].should be_true
      end
    end

    context 'when honeypot value is wrong' do
      before do
        UsersController.any_instance.stubs(:honeypot_value).returns('abc')
      end
      let(:create_params) { {name: @user.name, username: @user.username, password: "strongpassword", email: @user.email, password_confirmation: 'wrong'} }
      include_examples 'honeypot fails'
    end

    context 'when challenge answer is wrong' do
      before do
        UsersController.any_instance.stubs(:challenge_value).returns('abc')
      end
      let(:create_params) { {name: @user.name, username: @user.username, password: "strongpassword", email: @user.email, challenge: 'abc'} }
      include_examples 'honeypot fails'
    end

    context "when 'invite only' setting is enabled" do
      before { SiteSetting.expects(:invite_only?).returns(true) }

      let(:create_params) {{
        name: @user.name,
        username: @user.username,
        password: 'strongpassword',
        email: @user.email
      }}

      include_examples 'honeypot fails'
    end

    shared_examples 'failed signup' do
      it 'should not create a new User' do
        expect { xhr :post, :create, create_params }.to_not change { User.count }
      end

      it 'should report failed' do
        xhr :post, :create, create_params
        json = JSON::parse(response.body)
        json["success"].should_not be_true
      end
    end

    context 'when password is blank' do
      let(:create_params) { {name: @user.name, username: @user.username, password: "", email: @user.email} }
      include_examples 'failed signup'
    end

    context 'when password param is missing' do
      let(:create_params) { {name: @user.name, username: @user.username, email: @user.email} }
      include_examples 'failed signup'
    end

    context 'when username is unavailable in DiscourseHub' do
      before do
        SiteSetting.stubs(:call_discourse_hub?).returns(true)
        DiscourseHub.stubs(:register_username).raises(DiscourseHub::UsernameUnavailable.new(@user.name))
      end
      let(:create_params) {{
        name: @user.name,
        username: @user.username,
        password: 'strongpassword',
        email: @user.email
      }}

      include_examples 'failed signup'
    end

    context 'when an Exception is raised' do

      [ ActiveRecord::StatementInvalid,
        DiscourseHub::UsernameUnavailable,
        RestClient::Forbidden ].each do |exception|
        before { User.any_instance.stubs(:save).raises(exception) }

        let(:create_params) {
          { name: @user.name, username: @user.username,
            password: "strongpassword", email: @user.email}
        }

        include_examples 'failed signup'
      end
    end

  end

  context '.username' do
    it 'raises an error when not logged in' do
      lambda { xhr :put, :username, username: 'somename' }.should raise_error(Discourse::NotLoggedIn)
    end

    context 'while logged in' do
      let!(:user) { log_in }
      let(:new_username) { "#{user.username}1234" }

      it 'raises an error without a new_username param' do
        lambda { xhr :put, :username, username: user.username }.should raise_error(ActionController::ParameterMissing)
      end

      it 'raises an error when you don\'t have permission to change the username' do
        Guardian.any_instance.expects(:can_edit_username?).with(user).returns(false)
        xhr :put, :username, username: user.username, new_username: new_username
        response.should be_forbidden
      end

      it 'raises an error when change_username fails' do
        User.any_instance.expects(:change_username).with(new_username).returns(false)
        lambda { xhr :put, :username, username: user.username, new_username: new_username }.should raise_error(Discourse::InvalidParameters)
      end

      it 'should succeed when the change_username returns true' do
        User.any_instance.expects(:change_username).with(new_username).returns(true)
        xhr :put, :username, username: user.username, new_username: new_username
        response.should be_success
      end

    end
  end

  context '.check_username' do
    before do
      DiscourseHub.stubs(:username_available?).returns([true, nil])
    end

    it 'raises an error without any parameters' do
      lambda { xhr :get, :check_username }.should raise_error(ActionController::ParameterMissing)
    end

    shared_examples 'when username is unavailable locally' do
      it 'should return success' do
        response.should be_success
      end

      it 'should return available as false in the JSON' do
        ::JSON.parse(response.body)['available'].should be_false
      end

      it 'should return a suggested username' do
        ::JSON.parse(response.body)['suggestion'].should be_present
      end
    end

    shared_examples 'when username is available everywhere' do
      it 'should return success' do
        response.should be_success
      end

      it 'should return available in the JSON' do
        ::JSON.parse(response.body)['available'].should be_true
      end
    end

    context 'when call_discourse_hub is disabled' do
      before do
        SiteSetting.stubs(:call_discourse_hub?).returns(false)
        DiscourseHub.expects(:username_available?).never
        DiscourseHub.expects(:username_match?).never
      end

      it 'returns nothing when given an email param but no username' do
        xhr :get, :check_username, email: 'dood@example.com'
        response.should be_success
      end

      context 'username is available' do
        before do
          xhr :get, :check_username, username: 'BruceWayne'
        end
        include_examples 'when username is available everywhere'
      end

      context 'username is unavailable' do
        let!(:user) { Fabricate(:user) }
        before do
          xhr :get, :check_username, username: user.username
        end
        include_examples 'when username is unavailable locally'
      end

      shared_examples 'checking an invalid username' do
        it 'should return success' do
          response.should be_success
        end

        it 'should not return an available key' do
          ::JSON.parse(response.body)['available'].should be_nil
        end

        it 'should return an error message' do
          ::JSON.parse(response.body)['errors'].should_not be_empty
        end
      end

      context 'has invalid characters' do
        before do
          xhr :get, :check_username, username: 'bad username'
        end
        include_examples 'checking an invalid username'

        it 'should return the invalid characters message' do
          ::JSON.parse(response.body)['errors'].should include(I18n.t(:'user.username.characters'))
        end
      end

      context 'is too long' do
        before do
          xhr :get, :check_username, username: generate_username(User.username_length.last + 1)
        end
        include_examples 'checking an invalid username'

        it 'should return the "too long" message' do
          ::JSON.parse(response.body)['errors'].should include(I18n.t(:'user.username.long', max: User.username_length.end))
        end
      end
    end

    context 'when call_discourse_hub is enabled' do
      before do
        SiteSetting.stubs(:call_discourse_hub?).returns(true)
      end

      context 'available locally and globally' do
        before do
          DiscourseHub.stubs(:username_available?).returns([true, nil])
          DiscourseHub.stubs(:username_match?).returns([false, true, nil])  # match = false, available = true, suggestion = nil
        end

        shared_examples 'check_username when username is available everywhere' do
          it 'should return success' do
            response.should be_success
          end

          it 'should return available in the JSON' do
            ::JSON.parse(response.body)['available'].should be_true
          end

          it 'should return global_match false in the JSON' do
            ::JSON.parse(response.body)['global_match'].should be_false
          end
        end

        context 'and email is not given' do
          before do
            xhr :get, :check_username, username: 'BruceWayne'
          end
          include_examples 'check_username when username is available everywhere'
        end

        context 'both username and email is given' do
          before do
            xhr :get, :check_username, username: 'BruceWayne', email: 'brucie@gmail.com'
          end
          include_examples 'check_username when username is available everywhere'
        end

        context 'only email is given' do
          it "should check for a matching username" do
            UsernameCheckerService.any_instance.expects(:check_username).with(nil, 'brucie@gmail.com').returns({json: 'blah'})
            xhr :get, :check_username, email: 'brucie@gmail.com'
            response.should be_success
          end
        end
      end

      shared_examples 'when email is needed to check username match' do
        it 'should return success' do
          response.should be_success
        end

        it 'should return available as false in the JSON' do
          ::JSON.parse(response.body)['available'].should be_false
        end

        it 'should not return a suggested username' do
          ::JSON.parse(response.body)['suggestion'].should_not be_present
        end
      end

      context 'available locally but not globally' do
        before do
          DiscourseHub.stubs(:username_available?).returns([false, 'suggestion'])
        end

        context 'email param is not given' do
          before do
            xhr :get, :check_username, username: 'BruceWayne'
          end
          include_examples 'when email is needed to check username match'
        end

        context 'email param is an empty string' do
          before do
            xhr :get, :check_username, username: 'BruceWayne', email: ''
          end
          include_examples 'when email is needed to check username match'
        end

        context 'email matches global username' do
          before do
            DiscourseHub.stubs(:username_match?).returns([true, false, nil])
            xhr :get, :check_username, username: 'BruceWayne', email: 'brucie@example.com'
          end
          include_examples 'when username is available everywhere'

          it 'should indicate a global match' do
            ::JSON.parse(response.body)['global_match'].should be_true
          end
        end

        context 'email does not match global username' do
          before do
            DiscourseHub.stubs(:username_match?).returns([false, false, 'suggestion'])
            xhr :get, :check_username, username: 'BruceWayne', email: 'brucie@example.com'
          end
          include_examples 'when username is unavailable locally'

          it 'should not indicate a global match' do
            ::JSON.parse(response.body)['global_match'].should be_false
          end
        end
      end

      context 'unavailable locally and globally' do
        let!(:user) { Fabricate(:user) }

        before do
          DiscourseHub.stubs(:username_available?).returns([false, 'suggestion'])
          xhr :get, :check_username, username: user.username
        end

        include_examples 'when username is unavailable locally'
      end

      context 'unavailable locally and available globally' do
        let!(:user) { Fabricate(:user) }

        before do
          DiscourseHub.stubs(:username_available?).returns([true, nil])
          xhr :get, :check_username, username: user.username
        end

        include_examples 'when username is unavailable locally'
      end
    end

    context 'when discourse_org_access_key is wrong' do
      before do
        SiteSetting.stubs(:call_discourse_hub?).returns(true)
        DiscourseHub.stubs(:username_available?).raises(RestClient::Forbidden)
        DiscourseHub.stubs(:username_match?).raises(RestClient::Forbidden)
      end

      it 'should return an error message' do
        xhr :get, :check_username, username: 'horsie'
        json = JSON.parse(response.body)
        json['errors'].should_not be_nil
        json['errors'][0].should_not be_nil
      end
    end

    describe 'different case of existing username' do
      context "it's my username" do
        let!(:user) { Fabricate(:user, username: 'hansolo') }
        before do
          log_in_user(user)
          xhr :get, :check_username, username: 'HanSolo'
        end
        include_examples 'when username is available everywhere'
      end

      context "it's someone else's username" do
        let!(:user) { Fabricate(:user, username: 'hansolo') }
        before do
          log_in
          xhr :get, :check_username, username: 'HanSolo'
        end
        include_examples 'when username is unavailable locally'
      end

      context "an admin changing it for someone else" do
        let!(:user) { Fabricate(:user, username: 'hansolo') }
        before do
          log_in_user(Fabricate(:admin))
          xhr :get, :check_username, username: 'HanSolo', for_user_id: user.id
        end
        include_examples 'when username is available everywhere'
      end
    end
  end

  describe '#invited' do
    it 'returns success' do
      user = Fabricate(:user)

      xhr :get, :invited, username: user.username

      expect(response).to be_success
    end

    it 'filters by email' do
      inviter = Fabricate(:user)
      invitee = Fabricate(:user)
      invite = Fabricate(
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

      xhr :get, :invited, username: inviter.username, filter: 'billybob'

      invites = JSON.parse(response.body)['invites']
      expect(invites).to have(1).item
      expect(invites.first).to include('email' => 'billybob@example.com')
    end

    it 'filters by username' do
      inviter = Fabricate(:user)
      invitee = Fabricate(:user, username: 'billybob')
      invite = Fabricate(
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

      xhr :get, :invited, username: inviter.username, filter: 'billybob'

      invites = JSON.parse(response.body)['invites']
      expect(invites).to have(1).item
      expect(invites.first).to include('email' => 'billybob@example.com')
    end

    context 'with guest' do
      context 'with pending invites' do
        it 'does not return invites' do
          inviter = Fabricate(:user)
          Fabricate(:invite, invited_by: inviter)

          xhr :get, :invited, username: inviter.username

          invites = JSON.parse(response.body)['invites']
          expect(invites).to be_empty
        end
      end

      context 'with redeemed invites' do
        it 'returns invites' do
          inviter = Fabricate(:user)
          invitee = Fabricate(:user)
          invite = Fabricate(:invite, invited_by: inviter, user: invitee)

          xhr :get, :invited, username: inviter.username

          invites = JSON.parse(response.body)['invites']
          expect(invites).to have(1).item
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

            xhr :get, :invited, username: inviter.username

            invites = JSON.parse(response.body)['invites']
            expect(invites).to have(1).item
            expect(invites.first).to include("email" => invite.email)
          end
        end

        context 'without permission to see pending invites' do
          it 'does not return invites' do
            user = log_in
            inviter = Fabricate(:user)
            invitee = Fabricate(:user)
            Fabricate(:invite, invited_by: inviter)
            stub_guardian(user) do |guardian|
              guardian.stubs(:can_see_invite_details?).
                with(inviter).returns(false)
            end

            xhr :get, :invited, username: inviter.username

            json = JSON.parse(response.body)['invites']
            expect(json).to be_empty
          end
        end
      end

      context 'with redeemed invites' do
        it 'returns invites' do
          user = log_in
          inviter = Fabricate(:user)
          invitee = Fabricate(:user)
          invite = Fabricate(:invite, invited_by: inviter, user: invitee)

          xhr :get, :invited, username: inviter.username

          invites = JSON.parse(response.body)['invites']
          expect(invites).to have(1).item
          expect(invites.first).to include('email' => invite.email)
        end
      end
    end
  end

  describe '#update' do
    context 'with guest' do
      it 'raises an error' do
        expect do
          xhr :put, :update, username: 'guest'
        end.to raise_error(Discourse::NotLoggedIn)
      end
    end

    context 'with authenticated user' do
      context 'with permission to update' do
        it 'allows the update' do
          user = Fabricate(:user, name: 'Billy Bob')
          log_in_user(user)

          put :update, username: user.username, name: 'Jim Tom', custom_fields: {test: :it}

          expect(response).to be_success

          user.reload

          expect(user.name).to eq 'Jim Tom'
          expect(user.custom_fields['test']).to eq 'it'
        end

        it 'returns user JSON' do
          user = log_in

          put :update, username: user.username

          json = JSON.parse(response.body)
          expect(json['user']['id']).to eq user.id
        end
      end

      context 'without permission to update' do
        it 'does not allow the update' do
          user = Fabricate(:user, name: 'Billy Bob')
          log_in_user(user)
          guardian = Guardian.new(user)
          guardian.stubs(:ensure_can_edit!).with(user).raises(Discourse::InvalidAccess.new)
          Guardian.stubs(new: guardian).with(user)

          put :update, username: user.username, name: 'Jim Tom'

          expect(response).to be_forbidden
          expect(user.reload.name).not_to eq 'Jim Tom'
        end
      end
    end
  end

  describe "badge_title" do
    let(:user) { Fabricate(:user) }
    let(:badge) { Fabricate(:badge) }
    let(:user_badge) { BadgeGranter.grant(badge, user) }

    it "sets the user's title to the badge name if it is titleable" do
      log_in_user user
      xhr :put, :badge_title, user_badge_id: user_badge.id, username: user.username
      user.reload.title.should_not == badge.name
      badge.update_attributes allow_title: true
      xhr :put, :badge_title, user_badge_id: user_badge.id, username: user.username
      user.reload.title.should == badge.name
    end
  end

  describe "search_users" do

    let(:topic) { Fabricate :topic }
    let(:user)  { Fabricate :user, username: "joecabot", name: "Lawrence Tierney" }

    before do
      ActiveRecord::Base.observers.enable :all
      Fabricate :post, user: user, topic: topic
    end

    it "searches when provided the term only" do
      xhr :post, :search_users, term: user.name.split(" ").last
      response.should be_success
      json = JSON.parse(response.body)
      json["users"].map { |u| u["username"] }.should include(user.username)
    end

    it "searches when provided the topic only" do
      xhr :post, :search_users, topic_id: topic.id
      response.should be_success
      json = JSON.parse(response.body)
      json["users"].map { |u| u["username"] }.should include(user.username)
    end

    it "searches when provided the term and topic" do
      xhr :post, :search_users, term: user.name.split(" ").last, topic_id: topic.id
      response.should be_success
      json = JSON.parse(response.body)
      json["users"].map { |u| u["username"] }.should include(user.username)
    end

    context "when `enable_names` is true" do
      before do
        SiteSetting.enable_names = true
      end

      it "returns names" do
        xhr :post, :search_users, term: user.name
        json = JSON.parse(response.body)
        json["users"].map { |u| u["name"] }.should include(user.name)
      end
    end

    context "when `enable_names` is false" do
      before do
        SiteSetting.stubs(:enable_names?).returns(false)
      end

      it "returns names" do
        xhr :post, :search_users, term: user.name
        json = JSON.parse(response.body)
        json["users"].map { |u| u["name"] }.should_not include(user.name)
      end
    end

  end

  describe 'send_activation_email' do
    context 'for an existing user' do
      let(:user) { Fabricate(:user) }

      before do
        UsersController.any_instance.stubs(:fetch_user_from_params).returns(user)
      end

      context 'with a valid email_token' do
        it 'should send the activation email' do
          Jobs.expects(:enqueue).with(:user_email, has_entries(type: :signup))
          xhr :post, :send_activation_email, username: user.username
        end
      end

      context 'without an existing email_token' do
        before do
          user.email_tokens.each {|t| t.destroy}
          user.reload
        end

        it 'should generate a new token' do
          expect {
            xhr :post, :send_activation_email, username: user.username
          }.to change{ user.email_tokens(true).count }.by(1)
        end

        it 'should send an email' do
          Jobs.expects(:enqueue).with(:user_email, has_entries(type: :signup))
          xhr :post, :send_activation_email, username: user.username
        end
      end
    end

    context 'when username does not exist' do
      it 'should not send an email' do
        Jobs.expects(:enqueue).never
        xhr :post, :send_activation_email, username: 'nopenopenopenope'
      end
    end
  end

  describe '.upload_user_image' do

    it 'raises an error when not logged in' do
      lambda { xhr :put, :upload_user_image, username: 'asdf' }.should raise_error(Discourse::NotLoggedIn)
    end

    context 'while logged in' do

      let!(:user) { log_in }

      let(:logo) { File.new("#{Rails.root}/spec/fixtures/images/logo.png") }

      let(:user_image) do
        ActionDispatch::Http::UploadedFile.new({ filename: 'logo.png', tempfile: logo })
      end

      it 'raises an error without a image_type param' do
        lambda { xhr :put, :upload_user_image, username: user.username }.should raise_error(ActionController::ParameterMissing)
      end

      describe "with uploaded file" do

        it 'raises an error when you don\'t have permission to upload an user image' do
          Guardian.any_instance.expects(:can_edit?).with(user).returns(false)
          xhr :post, :upload_user_image, username: user.username, image_type: "avatar"
          response.should be_forbidden
        end

        it 'rejects large images' do
          SiteSetting.stubs(:max_image_size_kb).returns(1)
          xhr :post, :upload_user_image, username: user.username, file: user_image, image_type: "avatar"
          response.status.should eq 422
        end

        it 'rejects unauthorized images' do
          SiteSetting.stubs(:authorized_extensions).returns(".txt")
          xhr :post, :upload_user_image, username: user.username, file: user_image, image_type: "avatar"
          response.status.should eq 422
        end

        it 'is successful for avatars' do
          upload = Fabricate(:upload)
          Upload.expects(:create_for).returns(upload)
          # enqueues the user_image generator job
          xhr :post, :upload_user_image, username: user.username, file: user_image, image_type: "avatar"
          # returns the url, width and height of the uploaded image
          json = JSON.parse(response.body)
          json['url'].should == "/uploads/default/1/1234567890123456.png"
          json['width'].should == 100
          json['height'].should == 200
          json['upload_id'].should == upload.id
        end

        it 'is successful for profile backgrounds' do
          upload = Fabricate(:upload)
          Upload.expects(:create_for).returns(upload)
          xhr :post, :upload_user_image, username: user.username, file: user_image, image_type: "profile_background"
          user.reload

          user.user_profile.profile_background.should == "/uploads/default/1/1234567890123456.png"

          # returns the url, width and height of the uploaded image
          json = JSON.parse(response.body)
          json['url'].should == "/uploads/default/1/1234567890123456.png"
          json['width'].should == 100
          json['height'].should == 200
        end

      end

      describe "with url" do
        let(:user_image_url) { "http://cdn.discourse.org/assets/logo.png" }

        before { UsersController.any_instance.stubs(:is_api?).returns(true) }

        describe "correct urls" do

          before { FileHelper.stubs(:download).returns(logo) }

          it 'rejects large images' do
            SiteSetting.stubs(:max_image_size_kb).returns(1)
            xhr :post, :upload_user_image, username: user.username, file: user_image_url, image_type: "profile_background"
            response.status.should eq 422
          end

          it 'rejects unauthorized images' do
            SiteSetting.stubs(:authorized_extensions).returns(".txt")
            xhr :post, :upload_user_image, username: user.username, file: user_image_url, image_type: "profile_background"
            response.status.should eq 422
          end

          it 'is successful for avatars' do
            upload = Fabricate(:upload)
            Upload.expects(:create_for).returns(upload)
            # enqueues the user_image generator job
            xhr :post, :upload_avatar, username: user.username, file: user_image_url, image_type: "avatar"
            json = JSON.parse(response.body)
            json['url'].should == "/uploads/default/1/1234567890123456.png"
            json['width'].should == 100
            json['height'].should == 200
            json['upload_id'].should == upload.id
          end

          it 'is successful for profile backgrounds' do
            upload = Fabricate(:upload)
            Upload.expects(:create_for).returns(upload)
            xhr :post, :upload_user_image, username: user.username, file: user_image_url, image_type: "profile_background"
            user.reload
            user.user_profile.profile_background.should == "/uploads/default/1/1234567890123456.png"

            # returns the url, width and height of the uploaded image
            json = JSON.parse(response.body)
            json['url'].should == "/uploads/default/1/1234567890123456.png"
            json['width'].should == 100
            json['height'].should == 200
          end
        end

        it "should handle malformed urls" do
          xhr :post, :upload_user_image, username: user.username, file: "foobar", image_type: "profile_background"
          response.status.should eq 422
        end

      end

    end

  end

  describe '.pick_avatar' do

    it 'raises an error when not logged in' do
      lambda { xhr :put, :pick_avatar, username: 'asdf', avatar_id: 1}.should raise_error(Discourse::NotLoggedIn)
    end

    context 'while logged in' do

      let!(:user) { log_in }

      it 'raises an error when you don\'t have permission to toggle the avatar' do
        another_user = Fabricate(:user)
        xhr :put, :pick_avatar, username: another_user.username, upload_id: 1
        response.should be_forbidden
      end

      it 'it successful' do
        xhr :put, :pick_avatar, username: user.username, upload_id: 111
        user.reload.uploaded_avatar_id.should == 111
        response.should be_success

        xhr :put, :pick_avatar, username: user.username
        user.reload.uploaded_avatar_id.should == nil
        response.should be_success
      end

    end

  end

  describe '.destroy_user_image' do

    it 'raises an error when not logged in' do
      lambda { xhr :delete, :destroy_user_image, type: 'profile_background', username: 'asdf' }.should raise_error(Discourse::NotLoggedIn)
    end

    context 'while logged in' do

      let!(:user) { log_in }

      it 'raises an error when you don\'t have permission to clear the profile background' do
        Guardian.any_instance.expects(:can_edit?).with(user).returns(false)
        xhr :delete, :destroy_user_image, username: user.username, image_type: 'profile_background'
        response.should be_forbidden
      end

      it "requires the `image_type` param" do
        -> { xhr :delete, :destroy_user_image, username: user.username }.should raise_error(ActionController::ParameterMissing)
      end

      it "only allows certain `image_types`" do
        -> { xhr :delete, :destroy_user_image, username: user.username, image_type: 'wat' }.should raise_error(Discourse::InvalidParameters)
      end

      it 'can clear the profile background' do
        xhr :delete, :destroy_user_image, image_type: 'profile_background', username: user.username
        user.reload.user_profile.profile_background.should == ""
        response.should be_success
      end

    end
  end

  describe '.destroy' do
    it 'raises an error when not logged in' do
      lambda { xhr :delete, :destroy, username: 'nobody' }.should raise_error(Discourse::NotLoggedIn)
    end

    context 'while logged in' do
      let!(:user) { log_in }

      it 'raises an error when you cannot delete your account' do
        Guardian.any_instance.stubs(:can_delete_user?).returns(false)
        UserDestroyer.any_instance.expects(:destroy).never
        xhr :delete, :destroy, username: user.username
        response.should be_forbidden
      end

      it "raises an error when you try to delete someone else's account" do
        UserDestroyer.any_instance.expects(:destroy).never
        xhr :delete, :destroy, username: Fabricate(:user).username
        response.should be_forbidden
      end

      it "deletes your account when you're allowed to" do
        Guardian.any_instance.stubs(:can_delete_user?).returns(true)
        UserDestroyer.any_instance.expects(:destroy).with(user, anything).returns(user)
        xhr :delete, :destroy, username: user.username
        response.should be_success
      end
    end
  end

  describe '.my_redirect' do

    it "returns 404 if the user is not logged in" do
      get :my_redirect, path: "wat"
      response.should_not be_success
      response.should_not be_redirect
    end

    context "when the user is logged in" do
      let!(:user) { log_in }

      it "will not redirect to an invalid path" do
        get :my_redirect, path: "wat/..password.txt"
        response.should_not be_redirect
      end

      it "will redirect to an valid path" do
        get :my_redirect, path: "preferences"
        response.should be_redirect
      end

      it "permits forward slashes" do
        get :my_redirect, path: "activity/posts"
        response.should be_redirect
      end
    end
  end

end
