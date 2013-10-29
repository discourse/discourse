require 'spec_helper'

describe TopicsController do

  context 'wordpress' do
    let!(:user) { log_in(:moderator) }
    let(:p1) { Fabricate(:post, user: user) }
    let(:topic) { p1.topic }
    let!(:p2) { Fabricate(:post, topic: topic, user:user )}

    it "returns the JSON in the format our wordpress plugin needs" do
      xhr :get, :wordpress, topic_id: topic.id, best: 3
      response.should be_success
      json = ::JSON.parse(response.body)
      json.should be_present

      # The JSON has the data the wordpress plugin needs
      json['id'].should == topic.id
      json['posts_count'].should == 2
      json['filtered_posts_count'].should == 2

      # Posts
      json['posts'].size.should == 1
      post = json['posts'][0]
      post['id'].should == p2.id
      post['username'].should == user.username
      post['avatar_template'].should == user.avatar_template
      post['name'].should == user.name
      post['created_at'].should be_present
      post['cooked'].should == p2.cooked

      # Participants
      json['participants'].size.should == 1
      participant = json['participants'][0]
      participant['id'].should == user.id
      participant['username'].should == user.username
      participant['avatar_template'].should == user.avatar_template
    end
  end

  context 'move_posts' do
    it 'needs you to be logged in' do
      lambda { xhr :post, :move_posts, topic_id: 111, title: 'blah', post_ids: [1,2,3] }.should raise_error(Discourse::NotLoggedIn)
    end

    describe 'moving to a new topic' do
      let!(:user) { log_in(:moderator) }
      let(:p1) { Fabricate(:post, user: user) }
      let(:topic) { p1.topic }

      it "raises an error without postIds" do
        lambda { xhr :post, :move_posts, topic_id: topic.id, title: 'blah' }.should raise_error(ActionController::ParameterMissing)
      end

      it "raises an error when the user doesn't have permission to move the posts" do
        Guardian.any_instance.expects(:can_move_posts?).returns(false)
        xhr :post, :move_posts, topic_id: topic.id, title: 'blah', post_ids: [1,2,3]
        response.should be_forbidden
      end

      context 'success' do
        let(:p2) { Fabricate(:post, user: user) }

        before do
          Topic.any_instance.expects(:move_posts).with(user, [p2.id], title: 'blah', category_id: 123).returns(topic)
          xhr :post, :move_posts, topic_id: topic.id, title: 'blah', post_ids: [p2.id], category_id: 123
        end

        it "returns success" do
          response.should be_success
          result = ::JSON.parse(response.body)
          result['success'].should be_true
          result['url'].should be_present
        end
      end

      context 'failure' do
        let(:p2) { Fabricate(:post, user: user) }

        before do
          Topic.any_instance.expects(:move_posts).with(user, [p2.id], title: 'blah').returns(nil)
          xhr :post, :move_posts, topic_id: topic.id, title: 'blah', post_ids: [p2.id]
        end

        it "returns JSON with a false success" do
          response.should be_success
          result = ::JSON.parse(response.body)
          result['success'].should be_false
          result['url'].should be_blank
        end
      end
    end

    describe "moving replied posts" do
      let!(:user) { log_in(:moderator) }
      let!(:p1) { Fabricate(:post, user: user) }
      let!(:topic) { p1.topic }
      let!(:p2) { Fabricate(:post, topic: topic, user: user, reply_to_post_number: p1.post_number ) }

      context 'success' do

        before do
          PostReply.create(post_id: p1.id, reply_id: p2.id)
        end

        it "moves the child posts too" do
          Topic.any_instance.expects(:move_posts).with(user, [p1.id, p2.id], title: 'blah').returns(topic)
          xhr :post, :move_posts, topic_id: topic.id, title: 'blah', post_ids: [p1.id], reply_post_ids: [p1.id]
        end
      end

    end


    describe 'moving to an existing topic' do
      let!(:user) { log_in(:moderator) }
      let(:p1) { Fabricate(:post, user: user) }
      let(:topic) { p1.topic }
      let(:dest_topic) { Fabricate(:topic) }

      context 'success' do
        let(:p2) { Fabricate(:post, user: user) }

        before do
          Topic.any_instance.expects(:move_posts).with(user, [p2.id], destination_topic_id: dest_topic.id).returns(topic)
          xhr :post, :move_posts, topic_id: topic.id, post_ids: [p2.id], destination_topic_id: dest_topic.id
        end

        it "returns success" do
          response.should be_success
          result = ::JSON.parse(response.body)
          result['success'].should be_true
          result['url'].should be_present
        end
      end

      context 'failure' do
        let(:p2) { Fabricate(:post, user: user) }

        before do
          Topic.any_instance.expects(:move_posts).with(user, [p2.id], destination_topic_id: dest_topic.id).returns(nil)
          xhr :post, :move_posts, topic_id: topic.id, destination_topic_id: dest_topic.id, post_ids: [p2.id]
        end

        it "returns JSON with a false success" do
          response.should be_success
          result = ::JSON.parse(response.body)
          result['success'].should be_false
          result['url'].should be_blank
        end
      end
    end
  end

  context "merge_topic" do
    it 'needs you to be logged in' do
      lambda { xhr :post, :merge_topic, topic_id: 111, destination_topic_id: 345 }.should raise_error(Discourse::NotLoggedIn)
    end

    describe 'moving to a new topic' do
      let!(:user) { log_in(:moderator) }
      let(:p1) { Fabricate(:post, user: user) }
      let(:topic) { p1.topic }

      it "raises an error without destination_topic_id" do
        lambda { xhr :post, :merge_topic, topic_id: topic.id }.should raise_error(ActionController::ParameterMissing)
      end

      it "raises an error when the user doesn't have permission to merge" do
        Guardian.any_instance.expects(:can_move_posts?).returns(false)
        xhr :post, :merge_topic, topic_id: 111, destination_topic_id: 345
        response.should be_forbidden
      end

      let(:dest_topic) { Fabricate(:topic) }

      context 'moves all the posts to the destination topic' do
        let(:p2) { Fabricate(:post, user: user) }

        before do
          Topic.any_instance.expects(:move_posts).with(user, [p1.id], destination_topic_id: dest_topic.id).returns(topic)
          xhr :post, :merge_topic, topic_id: topic.id, destination_topic_id: dest_topic.id
        end

        it "returns success" do
          response.should be_success
          result = ::JSON.parse(response.body)
          result['success'].should be_true
          result['url'].should be_present
        end
      end


    end

  end

  context 'similar_to' do

    let(:title) { 'this title is long enough to search for' }
    let(:raw) { 'this body is long enough to search for' }

    it "requires a title" do
      -> { xhr :get, :similar_to, raw: raw }.should raise_error(ActionController::ParameterMissing)
    end

    it "requires a raw body" do
      -> { xhr :get, :similar_to, title: title }.should raise_error(ActionController::ParameterMissing)
    end

    it "raises an error if the title length is below the minimum" do
      SiteSetting.stubs(:min_title_similar_length).returns(100)
      -> { xhr :get, :similar_to, title: title, raw: raw }.should raise_error(Discourse::InvalidParameters)
    end

    it "raises an error if the body length is below the minimum" do
      SiteSetting.stubs(:min_body_similar_length).returns(100)
      -> { xhr :get, :similar_to, title: title, raw: raw }.should raise_error(Discourse::InvalidParameters)
    end

    describe "minimum_topics_similar" do

      before do
        SiteSetting.stubs(:minimum_topics_similar).returns(30)
      end

      after do
        xhr :get, :similar_to, title: title, raw: raw
      end

      describe "With enough topics" do
        before do
          Topic.stubs(:count).returns(50)
        end

        it "deletes to Topic.similar_to if there are more topics than `minimum_topics_similar`" do
          Topic.expects(:similar_to).with(title, raw, nil).returns([Fabricate(:topic)])
        end

        describe "with a logged in user" do
          let(:user) { log_in }

          it "passes a user through if logged in" do
            Topic.expects(:similar_to).with(title, raw, user).returns([Fabricate(:topic)])
          end
        end

      end

      it "does not call Topic.similar_to if there are fewer topics than `minimum_topics_similar`" do
        Topic.stubs(:count).returns(10)
        Topic.expects(:similar_to).never
      end

    end

  end


  context 'clear_pin' do
    it 'needs you to be logged in' do
      lambda { xhr :put, :clear_pin, topic_id: 1 }.should raise_error(Discourse::NotLoggedIn)
    end

    context 'when logged in' do
      let(:topic) { Fabricate(:topic) }
      let!(:user) { log_in }

      it "fails when the user can't see the topic" do
        Guardian.any_instance.expects(:can_see?).with(topic).returns(false)
        xhr :put, :clear_pin, topic_id: topic.id
        response.should_not be_success
      end

      describe 'when the user can see the topic' do
        it "calls clear_pin_for if the user can see the topic" do
          Topic.any_instance.expects(:clear_pin_for).with(user).once
          xhr :put, :clear_pin, topic_id: topic.id
        end

        it "succeeds" do
          xhr :put, :clear_pin, topic_id: topic.id
          response.should be_success
        end
      end

    end

  end

  context 'status' do
    it 'needs you to be logged in' do
      lambda { xhr :put, :status, topic_id: 1, status: 'visible', enabled: true }.should raise_error(Discourse::NotLoggedIn)
    end

    describe 'when logged in' do
      before do
        @user = log_in(:moderator)
        @topic = Fabricate(:topic, user: @user)
      end

      it "raises an exception if you can't change it" do
        Guardian.any_instance.expects(:can_moderate?).with(@topic).returns(false)
        xhr :put, :status, topic_id: @topic.id, status: 'visible', enabled: 'true'
        response.should be_forbidden
      end

      it 'requires the status parameter' do
        lambda { xhr :put, :status, topic_id: @topic.id, enabled: true }.should raise_error(ActionController::ParameterMissing)
      end

      it 'requires the enabled parameter' do
        lambda { xhr :put, :status, topic_id: @topic.id, status: 'visible' }.should raise_error(ActionController::ParameterMissing)
      end

      it 'raises an error with a status not in the whitelist' do
        lambda { xhr :put, :status, topic_id: @topic.id, status: 'title', enabled: 'true' }.should raise_error(Discourse::InvalidParameters)
      end

      it 'calls update_status on the forum topic with false' do
        Topic.any_instance.expects(:update_status).with('closed', false, @user)
        xhr :put, :status, topic_id: @topic.id, status: 'closed', enabled: 'false'
      end

      it 'calls update_status on the forum topic with true' do
        Topic.any_instance.expects(:update_status).with('closed', true, @user)
        xhr :put, :status, topic_id: @topic.id, status: 'closed', enabled: 'true'
      end

    end

  end

  context 'delete_timings' do

    it 'needs you to be logged in' do
      lambda { xhr :delete, :destroy_timings, topic_id: 1 }.should raise_error(Discourse::NotLoggedIn)
    end

    context 'when logged in' do
      before do
        @user = log_in
        @topic = Fabricate(:topic, user: @user)
        @topic_user = TopicUser.get(@topic, @topic.user)
      end

      it 'deletes the forum topic user record' do
        PostTiming.expects(:destroy_for).with(@user.id, @topic.id)
        xhr :delete, :destroy_timings, topic_id: @topic.id
      end

    end

  end


  describe 'mute/unmute' do

    it 'needs you to be logged in' do
      lambda { xhr :put, :mute, topic_id: 99}.should raise_error(Discourse::NotLoggedIn)
    end

    it 'needs you to be logged in' do
      lambda { xhr :put, :unmute, topic_id: 99}.should raise_error(Discourse::NotLoggedIn)
    end

    describe 'when logged in' do
      before do
        @topic = Fabricate(:topic, user: log_in)
      end

      it "changes the user's starred flag when the parameter is present" do
        Topic.any_instance.expects(:toggle_mute).with(@topic.user)
        xhr :put, :mute, topic_id: @topic.id, starred: 'true'
      end

      it "removes the user's starred flag when the parameter is not true" do
        Topic.any_instance.expects(:toggle_mute).with(@topic.user)
        xhr :put, :unmute, topic_id: @topic.id, starred: 'false'
      end

    end

  end

  describe 'star' do

    it 'needs you to be logged in' do
      lambda { xhr :put, :star, topic_id: 1, starred: true }.should raise_error(Discourse::NotLoggedIn)
    end

    describe 'when logged in' do
      before do
        @topic = Fabricate(:topic, user: log_in)
      end

      it "ensures the user can see the topic" do
        Guardian.any_instance.expects(:can_see?).with(@topic).returns(false)
        xhr :put, :star, topic_id: @topic.id, starred: 'true'
        response.should be_forbidden
      end

      it "changes the user's starred flag when the parameter is present" do
        Topic.any_instance.expects(:toggle_star).with(@topic.user, true)
        xhr :put, :star, topic_id: @topic.id, starred: 'true'
      end

      it "removes the user's starred flag when the parameter is not true" do
        Topic.any_instance.expects(:toggle_star).with(@topic.user, false)
        xhr :put, :star, topic_id: @topic.id, starred: 'false'
      end
    end
  end

  describe 'recover' do
    it "won't allow us to recover a topic when we're not logged in" do
      lambda { xhr :put, :recover, topic_id: 1 }.should raise_error(Discourse::NotLoggedIn)
    end

    describe 'when logged in' do
      let(:topic) { Fabricate(:topic, user: log_in, deleted_at: Time.now, deleted_by: log_in) }

      describe 'without access' do
        it "raises an exception when the user doesn't have permission to delete the topic" do
          Guardian.any_instance.expects(:can_recover_topic?).with(topic).returns(false)
          xhr :put, :recover, topic_id: topic.id
          response.should be_forbidden
        end
      end

      context 'with permission' do
        before do
          Guardian.any_instance.expects(:can_recover_topic?).with(topic).returns(true)
        end

        it 'succeeds' do
          Topic.any_instance.expects(:recover!)
          xhr :put, :recover, topic_id: topic.id
          response.should be_success
        end
      end
    end

  end

  describe 'delete' do
    it "won't allow us to delete a topic when we're not logged in" do
      lambda { xhr :delete, :destroy, id: 1 }.should raise_error(Discourse::NotLoggedIn)
    end

    describe 'when logged in' do
      before do
        @topic = Fabricate(:topic, user: log_in)
      end

      describe 'without access' do
        it "raises an exception when the user doesn't have permission to delete the topic" do
          Guardian.any_instance.expects(:can_delete?).with(@topic).returns(false)
          xhr :delete, :destroy, id: @topic.id
          response.should be_forbidden
        end
      end

      describe 'with permission' do
        before do
          Guardian.any_instance.expects(:can_delete?).with(@topic).returns(true)
        end

        it 'succeeds' do
          xhr :delete, :destroy, id: @topic.id
          response.should be_success
        end

        it 'deletes the topic' do
          xhr :delete, :destroy, id: @topic.id
          Topic.exists?(id: @topic_id).should be_false
        end

      end

    end
  end

  describe 'show' do

    let(:topic) { Fabricate(:post).topic }
    let!(:p1) { Fabricate(:post, user: topic.user) }
    let!(:p2) { Fabricate(:post, user: topic.user) }

    it 'shows a topic correctly' do
      xhr :get, :show, topic_id: topic.id, slug: topic.slug
      response.should be_success
    end

    it 'can find a topic given a slug in the id param' do
      xhr :get, :show, id: topic.slug
      expect(response).to redirect_to(topic.relative_url)
    end

    it 'returns 404 when an invalid slug is given and no id' do
      xhr :get, :show, id: 'nope-nope'
      expect(response.status).to eq(404)
    end

    it 'returns a 404 when slug and topic id do not match a topic' do
      xhr :get, :show, topic_id: 123123, slug: 'topic-that-is-made-up'
      expect(response.status).to eq(404)
    end

    context 'a topic with nil slug exists' do
      before do
        @nil_slug_topic = Fabricate(:topic)
        Topic.connection.execute("update topics set slug=null where id = #{@nil_slug_topic.id}") # can't find a way to set slug column to null using the model
      end

      it 'returns a 404 when slug and topic id do not match a topic' do
        xhr :get, :show, topic_id: 123123, slug: 'topic-that-is-made-up'
        expect(response.status).to eq(404)
      end
    end

    it 'records a view' do
      lambda { xhr :get, :show, topic_id: topic.id, slug: topic.slug }.should change(View, :count).by(1)
    end

    it 'tracks a visit for all html requests' do
      current_user = log_in(:coding_horror)
      TopicUser.expects(:track_visit!).with(topic.id, current_user.id)
      get :show, topic_id: topic.id, slug: topic.slug
    end

    context 'consider for a promotion' do
      let!(:user) { log_in(:coding_horror) }
      let(:promotion) do
        result = mock
        Promotion.stubs(:new).with(user).returns(result)
        result
      end

      it "reviews the user for a promotion if they're new" do
        user.update_column(:trust_level, TrustLevel.levels[:newuser])
        Promotion.any_instance.expects(:review)
        get :show, topic_id: topic.id, slug: topic.slug
      end
    end

    context 'filters' do

      it 'grabs first page when no filter is provided' do
        SiteSetting.stubs(:posts_per_page).returns(20)
        TopicView.any_instance.expects(:filter_posts_in_range).with(0, 19)
        xhr :get, :show, topic_id: topic.id, slug: topic.slug
      end

      it 'grabs first page when first page is provided' do
        SiteSetting.stubs(:posts_per_page).returns(20)
        TopicView.any_instance.expects(:filter_posts_in_range).with(0, 19)
        xhr :get, :show, topic_id: topic.id, slug: topic.slug, page: 1
      end

      it 'grabs correct range when a page number is provided' do
        SiteSetting.stubs(:posts_per_page).returns(20)
        TopicView.any_instance.expects(:filter_posts_in_range).with(20, 39)
        xhr :get, :show, topic_id: topic.id, slug: topic.slug, page: 2
      end

      it 'delegates a post_number param to TopicView#filter_posts_near' do
        TopicView.any_instance.expects(:filter_posts_near).with(p2.post_number)
        xhr :get, :show, topic_id: topic.id, slug: topic.slug, post_number: p2.post_number
      end
    end

    context "when 'login required' site setting has been enabled" do
      before { SiteSetting.stubs(:login_required?).returns(true) }

      context 'and the user is logged in' do
        before { log_in(:coding_horror) }

        it 'shows the topic' do
          get :show, topic_id: topic.id, slug: topic.slug
          expect(response).to be_successful
        end
      end

      context 'and the user is not logged in' do
        it 'redirects to the login page' do
          get :show, topic_id: topic.id, slug: topic.slug
          expect(response).to redirect_to login_path
        end
      end
    end
  end

  describe '#feed' do
    let(:topic) { Fabricate(:post).topic }

    it 'renders rss of the topic' do
      get :feed, topic_id: topic.id, slug: 'foo', format: :rss
      response.should be_success
      response.content_type.should == 'application/rss+xml'
    end
  end

  describe 'update' do
    it "won't allow us to update a topic when we're not logged in" do
      lambda { xhr :put, :update, topic_id: 1, slug: 'xyz' }.should raise_error(Discourse::NotLoggedIn)
    end

    describe 'when logged in' do
      before do
        @topic = Fabricate(:topic, user: log_in)
      end

      describe 'without permission' do
        it "raises an exception when the user doesn't have permission to update the topic" do
          Guardian.any_instance.expects(:can_edit?).with(@topic).returns(false)
          xhr :put, :update, topic_id: @topic.id, slug: @topic.title
          response.should be_forbidden
        end
      end

      describe 'with permission' do
        before do
          Guardian.any_instance.expects(:can_edit?).with(@topic).returns(true)
        end

        it 'succeeds' do
          xhr :put, :update, topic_id: @topic.id, slug: @topic.title
          response.should be_success
          ::JSON.parse(response.body)['basic_topic'].should be_present
        end

        it 'allows a change of title' do
          xhr :put, :update, topic_id: @topic.id, slug: @topic.title, title: 'This is a new title for the topic'
          @topic.reload
          @topic.title.should == 'This is a new title for the topic'
        end

        it 'triggers a change of category' do
          Topic.any_instance.expects(:change_category).with('incredible').returns(true)
          xhr :put, :update, topic_id: @topic.id, slug: @topic.title, category: 'incredible'
        end

        it "returns errors with invalid titles" do
          xhr :put, :update, topic_id: @topic.id, slug: @topic.title, title: 'asdf'
          expect(response).not_to be_success
        end

        it "returns errors with invalid categories" do
          Topic.any_instance.expects(:change_category).returns(false)
          xhr :put, :update, topic_id: @topic.id, slug: @topic.title, category: ''
          expect(response).not_to be_success
        end

        context "allow_uncategorized_topics is false" do
          before do
            SiteSetting.stubs(:allow_uncategorized_topics).returns(false)
          end

          it "can add a category to an uncategorized topic" do
            Topic.any_instance.expects(:change_category).with('incredible').returns(true)
            xhr :put, :update, topic_id: @topic.id, slug: @topic.title, category: 'incredible'
            response.should be_success
          end
        end

      end
    end
  end

  describe 'invite' do
    it "won't allow us to invite toa topic when we're not logged in" do
      lambda { xhr :post, :invite, topic_id: 1, email: 'jake@adventuretime.ooo' }.should raise_error(Discourse::NotLoggedIn)
    end

    describe 'when logged in' do
      before do
        @topic = Fabricate(:topic, user: log_in)
      end

      it 'requires an email parameter' do
        lambda { xhr :post, :invite, topic_id: @topic.id }.should raise_error(ActionController::ParameterMissing)
      end

      describe 'without permission' do
        it "raises an exception when the user doesn't have permission to invite to the topic" do
          Guardian.any_instance.expects(:can_invite_to?).with(@topic).returns(false)
          xhr :post, :invite, topic_id: @topic.id, user: 'jake@adventuretime.ooo'
          response.should be_forbidden
        end
      end

      describe 'with permission' do

        before do
          Guardian.any_instance.expects(:can_invite_to?).with(@topic).returns(true)
        end

        context 'when it returns an invite' do
          before do
            Topic.any_instance.expects(:invite_by_email).with(@topic.user, 'jake@adventuretime.ooo').returns(Invite.new)
            xhr :post, :invite, topic_id: @topic.id, user: 'jake@adventuretime.ooo'
          end

          it 'should succeed' do
            response.should be_success
          end

          it 'returns success JSON' do
            ::JSON.parse(response.body).should == {'success' => 'OK'}
          end
        end

        context 'when it fails and returns nil' do

          before do
            Topic.any_instance.expects(:invite_by_email).with(@topic.user, 'jake@adventuretime.ooo').returns(nil)
            xhr :post, :invite, topic_id: @topic.id, user: 'jake@adventuretime.ooo'
          end

          it 'should succeed' do
            response.should_not be_success
          end

          it 'returns success JSON' do
            ::JSON.parse(response.body).should == {'failed' => 'FAILED'}
          end

        end

      end



    end

  end

  describe 'autoclose' do

    it 'needs you to be logged in' do
      lambda { xhr :put, :autoclose, topic_id: 99, auto_close_days: 3}.should raise_error(Discourse::NotLoggedIn)
    end

    it 'needs you to be an admin or mod' do
      user = log_in
      xhr :put, :autoclose, topic_id: 99, auto_close_days: 3
      response.should be_forbidden
    end

    describe 'when logged in' do
      before do
        @admin = log_in(:admin)
        @topic = Fabricate(:topic, user: @admin)
      end

      it "can set a topic's auto close time" do
        Topic.any_instance.expects(:set_auto_close).with("3", @admin)
        xhr :put, :autoclose, topic_id: @topic.id, auto_close_days: 3
      end

      it "can remove a topic's auto close time" do
        Topic.any_instance.expects(:set_auto_close).with(nil, anything)
        xhr :put, :autoclose, topic_id: @topic.id, auto_close_days: nil
      end
    end

  end

end
