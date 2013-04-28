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
    context 'invalid token' do
      before do
        EmailToken.expects(:confirm).with('asdfasdf').returns(nil)
        get :authorize_email, token: 'asdfasdf'
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

      before do
        EmailToken.expects(:confirm).with('asdfasdf').returns(user)
        get :authorize_email, token: 'asdfasdf'
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

      context 'reponse' do
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
        lambda { xhr :put, :change_email, username: user.username }.should raise_error(Discourse::InvalidParameters)
      end

      it "raises an error if you can't edit the user" do
        Guardian.any_instance.expects(:can_edit?).with(user).returns(false)
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

    context 'invalid token' do
      before do
        EmailToken.expects(:confirm).with('asdfasdf').returns(nil)
        get :password_reset, token: 'asdfasdf'
      end

      it 'return success' do
        response.should be_success
      end

      it 'sets a flash error' do
        flash[:error].should be_present
      end

      it "doesn't log in the user" do
        session[:current_user_id].should be_blank
      end
    end

    context 'valid token' do
      before do
        EmailToken.expects(:confirm).with('asdfasdf').returns(user)
        get :password_reset, token: 'asdfasdf'
      end

      it 'returns success' do
        response.should be_success
      end

      it "doesn't set an error" do
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


  describe '.create' do
    before do
      @user = Fabricate.build(:user)
      @user.password = "strongpassword"
      DiscourseHub.stubs(:register_nickname).returns([true, nil])
    end

    context 'when creating a non active user (unconfirmed email)' do
      it 'should enqueue a signup email' do
        Jobs.expects(:enqueue).with(:user_email, has_entries(type: :signup))
        xhr :post, :create, name: @user.name, username: @user.username,
                            password: "strongpassword", email: @user.email
      end

      it "doesn't send a welcome email" do
        User.any_instance.expects(:enqueue_welcome_message).with('welcome_user').never
        xhr :post, :create, name: @user.name, username: @user.username,
                            password: "strongpassword", email: @user.email
      end
    end

    context 'when creating an active user (confirmed email)' do

      before do
        User.any_instance.stubs(:active?).returns(true)
      end

      it 'should enqueue a signup email' do
        User.any_instance.expects(:enqueue_welcome_message).with('welcome_user')
        xhr :post, :create, name: @user.name, username: @user.username,
                            password: "strongpassword", email: @user.email
      end

      it "should be logged in" do
        User.any_instance.expects(:enqueue_welcome_message)
        xhr :post, :create, name: @user.name, username: @user.username, password: "strongpassword", email: @user.email
        session[:current_user_id].should be_present
      end

      it "returns true in the active part of the JSON" do
        User.any_instance.expects(:enqueue_welcome_message)
        xhr :post, :create, name: @user.name, username: @user.username, password: "strongpassword", email: @user.email
        ::JSON.parse(response.body)['active'].should == true
      end


      context 'when approving of users is required' do
        before do
          SiteSetting.expects(:must_approve_users).returns(true)
          xhr :post, :create, name: @user.name, username: @user.username, password: "strongpassword", email: @user.email
        end

        it "doesn't log in the user" do
          session[:current_user_id].should be_blank
        end

        it "doesn't return active in the JSON" do
          ::JSON.parse(response.body)['active'].should == false
        end
      end

      context 'authentication records for' do

        before do
          SiteSetting.expects(:must_approve_users).returns(true)
        end

        it 'should create twitter user info if none exists' do
          twitter_auth = { twitter_user_id: 42, twitter_screen_name: "bruce" }
          session[:authentication] = twitter_auth
          TwitterUserInfo.expects(:find_by_twitter_user_id).returns(nil)
          TwitterUserInfo.expects(:create)

          xhr :post, :create, name: @user.name, username: @user.username,
            password: "strongpassword", email: @user.email
        end

        it 'should create facebook user info if none exists' do
          fb_auth = { facebook: { facebook_user_id: 42} }
          session[:authentication] = fb_auth
          FacebookUserInfo.expects(:find_by_facebook_user_id).returns(nil)
          FacebookUserInfo.expects(:create!)

          xhr :post, :create, name: @user.name, username: @user.username,
                              password: "strongpassword", email: @user.email
        end

        it 'should create github user info if none exists' do
          gh_auth = { github_user_id: 2, github_screen_name: "bruce" }
          session[:authentication] = gh_auth
          GithubUserInfo.expects(:find_by_github_user_id).returns(nil)
          GithubUserInfo.expects(:create)

          xhr :post, :create, name: @user.name, username: @user.username,
                              password: "strongpassword", email: @user.email
        end

      end
    end

    context 'after success' do
      before do
        xhr :post, :create, name: @user.name, username: @user.username,
                            password: "strongpassword", email: @user.email
      end

      it 'should succeed' do
        should respond_with(:success)
      end

      it 'has the proper JSON' do
        json = JSON::parse(response.body)
        json["success"].should be_true
      end

      it 'should not result in an active account' do
        User.where(username: @user.username).first.active.should be_false
      end
    end

    shared_examples_for 'honeypot fails' do
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
      it_should_behave_like 'honeypot fails'
    end

    context 'when challenge answer is wrong' do
      before do
        UsersController.any_instance.stubs(:challenge_value).returns('abc')
      end
      let(:create_params) { {name: @user.name, username: @user.username, password: "strongpassword", email: @user.email, challenge: 'abc'} }
      it_should_behave_like 'honeypot fails'
    end

    shared_examples_for 'failed signup' do
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
      it_should_behave_like 'failed signup'
    end

    context 'when password param is missing' do
      let(:create_params) { {name: @user.name, username: @user.username, email: @user.email} }
      it_should_behave_like 'failed signup'
    end

    context 'when an Exception is raised' do

      [ ActiveRecord::StatementInvalid,
        DiscourseHub::NicknameUnavailable,
        RestClient::Forbidden ].each do |exception|
        before { User.any_instance.stubs(:save).raises(exception) }

        let(:create_params) {
          { name: @user.name, username: @user.username,
            password: "strongpassword", email: @user.email}
        }

        it_should_behave_like 'failed signup'
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
        lambda { xhr :put, :username, username: user.username }.should raise_error(Discourse::InvalidParameters)
      end

      it 'raises an error when you don\'t have permission to change the user' do
        Guardian.any_instance.expects(:can_edit?).with(user).returns(false)
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
      DiscourseHub.stubs(:nickname_available?).returns([true, nil])
    end

    it 'raises an error without a username parameter' do
      lambda { xhr :get, :check_username }.should raise_error(Discourse::InvalidParameters)
    end

    shared_examples_for 'when username is unavailable locally' do
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

    shared_examples_for 'when username is available everywhere' do
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
        DiscourseHub.expects(:nickname_available?).never
        DiscourseHub.expects(:nickname_match?).never
      end

      context 'available everywhere' do
        before do
          xhr :get, :check_username, username: 'BruceWayne'
        end
        it_should_behave_like 'when username is available everywhere'
      end

      context 'available locally but not globally' do
        before do
          xhr :get, :check_username, username: 'BruceWayne'
        end
        it_should_behave_like 'when username is available everywhere'
      end

      context 'unavailable locally but available globally' do
        let!(:user) { Fabricate(:user) }
        before do
          xhr :get, :check_username, username: user.username
        end
        it_should_behave_like 'when username is unavailable locally'
      end

      context 'unavailable everywhere' do
        let!(:user) { Fabricate(:user) }
        before do
          xhr :get, :check_username, username: user.username
        end
        it_should_behave_like 'when username is unavailable locally'
      end

      shared_examples_for 'checking an invalid username' do
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
        it_should_behave_like 'checking an invalid username'

        it 'should return the invalid characters message' do
          ::JSON.parse(response.body)['errors'].should include(I18n.t(:'user.username.characters'))
        end
      end

      context 'is too long' do
        before do
          xhr :get, :check_username, username: 'abcdefghijklmnop'
        end
        it_should_behave_like 'checking an invalid username'

        it 'should return the "too short" message' do
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
          DiscourseHub.stubs(:nickname_available?).returns([true, nil])
          DiscourseHub.stubs(:nickname_match?).returns([false, true, nil])  # match = false, available = true, suggestion = nil
        end

        shared_examples_for 'check_username when nickname is available everywhere' do
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
          it_should_behave_like 'check_username when nickname is available everywhere'
        end

        context 'and email is given' do
          before do
            xhr :get, :check_username, username: 'BruceWayne', email: 'brucie@gmail.com'
          end
          it_should_behave_like 'check_username when nickname is available everywhere'
        end
      end

      shared_examples_for 'when email is needed to check nickname match' do
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
          DiscourseHub.stubs(:nickname_available?).returns([false, 'suggestion'])
        end

        context 'email param is not given' do
          before do
            xhr :get, :check_username, username: 'BruceWayne'
          end
          it_should_behave_like 'when email is needed to check nickname match'
        end

        context 'email param is an empty string' do
          before do
            xhr :get, :check_username, username: 'BruceWayne', email: ''
          end
          it_should_behave_like 'when email is needed to check nickname match'
        end

        context 'email matches global nickname' do
          before do
            DiscourseHub.stubs(:nickname_match?).returns([true, false, nil])
            xhr :get, :check_username, username: 'BruceWayne', email: 'brucie@example.com'
          end
          it_should_behave_like 'when username is available everywhere'

          it 'should indicate a global match' do
            ::JSON.parse(response.body)['global_match'].should be_true
          end
        end

        context 'email does not match global nickname' do
          before do
            DiscourseHub.stubs(:nickname_match?).returns([false, false, 'suggestion'])
            xhr :get, :check_username, username: 'BruceWayne', email: 'brucie@example.com'
          end
          it_should_behave_like 'when username is unavailable locally'

          it 'should not indicate a global match' do
            ::JSON.parse(response.body)['global_match'].should be_false
          end
        end
      end

      context 'unavailable locally and globally' do
        let!(:user) { Fabricate(:user) }

        before do
          DiscourseHub.stubs(:nickname_available?).returns([false, 'suggestion'])
          xhr :get, :check_username, username: user.username
        end

        it_should_behave_like 'when username is unavailable locally'
      end

      context 'unavailable locally and available globally' do
        let!(:user) { Fabricate(:user) }

        before do
          DiscourseHub.stubs(:nickname_available?).returns([true, nil])
          xhr :get, :check_username, username: user.username
        end

        it_should_behave_like 'when username is unavailable locally'
      end
    end

    context 'when discourse_org_access_key is wrong' do
      before do
        SiteSetting.stubs(:call_discourse_hub?).returns(true)
        DiscourseHub.stubs(:nickname_available?).raises(RestClient::Forbidden)
        DiscourseHub.stubs(:nickname_match?).raises(RestClient::Forbidden)
      end

      it 'should return an error message' do
        xhr :get, :check_username, username: 'horsie'
        json = JSON.parse(response.body)
        json['errors'].should_not be_nil
        json['errors'][0].should_not be_nil
      end
    end
  end

  describe '.invited' do

    let(:user) { Fabricate(:user) }

    it 'returns success' do
      xhr :get, :invited, username: user.username
      response.should be_success
    end

  end

  describe '.update' do

    context 'not logged in' do
      it 'raises an error when not logged in' do
        expect do
          xhr :put, :update, username: 'somename'
        end.to raise_error(Discourse::NotLoggedIn)
      end
    end

    context 'logged in' do
      let!(:user) { log_in }

      context 'without a token' do
        it 'should ensure you can update the user' do
          Guardian.any_instance.expects(:can_edit?).with(user).returns(false)
          put :update, username: user.username
          response.should be_forbidden
        end

        context 'as a user who can edit the user' do

          before do
            put :update, username: user.username, bio_raw: 'brand new bio'
            user.reload
          end

          it 'updates the user' do
            user.bio_raw.should == 'brand new bio'
          end

          it 'returns json success' do
            response.should be_success
          end
        end
      end
    end
  end

  describe "search_users" do

    let(:topic) { Fabricate :topic }
    let(:user)  { Fabricate :user, username: "joecabot", name: "Lawrence Tierney" }

    before do
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
          xhr :get, :send_activation_email, username: user.username
        end
      end

      context 'without an existing email_token' do
        before do
          user.email_tokens.each {|t| t.destroy}
          user.reload
        end

        it 'should generate a new token' do
          expect {
            xhr :get, :send_activation_email, username: user.username
          }.to change{ user.email_tokens(true).count }.by(1)
        end

        it 'should send an email' do
          Jobs.expects(:enqueue).with(:user_email, has_entries(type: :signup))
          xhr :get, :send_activation_email, username: user.username
        end
      end
    end

    context 'when username does not exist' do
      it 'should not send an email' do
        Jobs.expects(:enqueue).never
        xhr :get, :send_activation_email, username: 'nopenopenopenope'
      end
    end
  end

end
