require 'spec_helper'

describe TopicsController do

  context 'move_posts' do
    it 'needs you to be logged in' do
      lambda { xhr :post, :move_posts, topic_id: 111, title: 'blah', post_ids: [1,2,3] }.should raise_error(Discourse::NotLoggedIn)
    end

    describe 'when logged in' do
      let!(:user) { log_in(:moderator) }
      let(:p1) { Fabricate(:post, user: user) }
      let(:topic) { p1.topic }

      it "raises an error without a title" do
        lambda { xhr :post, :move_posts, topic_id: topic.id, post_ids: [1,2,3] }.should raise_error(Discourse::InvalidParameters)
      end

      it "raises an error without postIds" do
        lambda { xhr :post, :move_posts, topic_id: topic.id, title: 'blah' }.should raise_error(Discourse::InvalidParameters)
      end

      it "raises an error when the user doesn't have permission to move the posts" do
        Guardian.any_instance.expects(:can_move_posts?).returns(false)
        xhr :post, :move_posts, topic_id: topic.id, title: 'blah', post_ids: [1,2,3]
        response.should be_forbidden
      end

      context 'success' do
        let(:p2) { Fabricate(:post, user: user) }

        before do
          Topic.any_instance.expects(:move_posts).with(user, 'blah', [p2.id]).returns(topic)
          xhr :post, :move_posts, topic_id: topic.id, title: 'blah', post_ids: [p2.id]
        end

        it "returns success" do
          response.should be_success
        end

        it "has a JSON response" do
          ::JSON.parse(response.body)['success'].should be_true
        end

        it "has a url" do
          ::JSON.parse(response.body)['url'].should be_present
        end
      end

      context 'failure' do
        let(:p2) { Fabricate(:post, user: user) }

        before do
          Topic.any_instance.expects(:move_posts).with(user, 'blah', [p2.id]).returns(nil)
          xhr :post, :move_posts, topic_id: topic.id, title: 'blah', post_ids: [p2.id]
        end

        it "returns success" do
          response.should be_success
        end

        it "has success in the JSON" do
          ::JSON.parse(response.body)['success'].should be_false
        end

        it "has a url" do
          ::JSON.parse(response.body)['url'].should be_blank
        end

      end

    end
  end

  context 'similar_to' do

    let(:title) { 'this title is long enough to search for' }
    let(:raw) { 'this body is long enough to search for' }

    it "requires a title" do
      -> { xhr :get, :similar_to, raw: raw }.should raise_error(Discourse::InvalidParameters)
    end

    it "requires a raw body" do
      -> { xhr :get, :similar_to, title: title }.should raise_error(Discourse::InvalidParameters)
    end

    it "raises an error if the title length is below the minimum" do
      SiteSetting.stubs(:min_title_similar_length).returns(100)
      -> { xhr :get, :similar_to, title: title, raw: raw }.should raise_error(Discourse::InvalidParameters)
    end

    it "raises an error if the body length is below the minimum" do
      SiteSetting.stubs(:min_body_similar_length).returns(100)
      -> { xhr :get, :similar_to, title: title, raw: raw }.should raise_error(Discourse::InvalidParameters)
    end

    it "delegates to Topic.similar_to" do
      Topic.expects(:similar_to).with(title, raw).returns([Fabricate(:topic)])
      xhr :get, :similar_to, title: title, raw: raw
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
        lambda { xhr :put, :status, topic_id: @topic.id, enabled: true }.should raise_error(Discourse::InvalidParameters)
      end

      it 'requires the enabled parameter' do
        lambda { xhr :put, :status, topic_id: @topic.id, status: 'visible' }.should raise_error(Discourse::InvalidParameters)
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
        Topic.any_instance.expects(:toggle_mute).with(@topic.user, true)
        xhr :put, :mute, topic_id: @topic.id, starred: 'true'
      end

      it "removes the user's starred flag when the parameter is not true" do
        Topic.any_instance.expects(:toggle_mute).with(@topic.user, false)
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
      xhr :get, :show, id: topic.id
      response.should be_success
    end

    it 'records a view' do
      lambda { xhr :get, :show, id: topic.id }.should change(View, :count).by(1)
    end

    it 'tracks a visit for all html requests' do
      current_user = log_in(:coding_horror)
      TopicUser.expects(:track_visit!).with(topic, current_user)
      get :show, id: topic.id
    end

    context 'consider for a promotion' do
      let!(:user) { log_in(:coding_horror) }
      let(:promotion) do
        result = mock
        Promotion.stubs(:new).with(user).returns(result)
        result
      end

      it "reviews the user for a promotion if they're new" do
        user.update_column(:trust_level, TrustLevel.levels[:visitor])
        Promotion.any_instance.expects(:review)
        get :show, id: topic.id
      end
    end

    context 'filters' do


      it 'grabs first page when no post number is selected' do
        TopicView.any_instance.expects(:filter_posts_paged).with(0)
        xhr :get, :show, id: topic.id
      end

      it 'delegates a post_number param to TopicView#filter_posts_near' do
        TopicView.any_instance.expects(:filter_posts_near).with(p2.post_number)
        xhr :get, :show, id: topic.id, post_number: p2.post_number
      end

      it 'delegates a posts_after param to TopicView#filter_posts_after' do
        TopicView.any_instance.expects(:filter_posts_after).with(p1.post_number)
        xhr :get, :show, id: topic.id, posts_after: p1.post_number
      end

      it 'delegates a posts_before param to TopicView#filter_posts_before' do
        TopicView.any_instance.expects(:filter_posts_before).with(p2.post_number)
        xhr :get, :show, id: topic.id, posts_before: p2.post_number
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
        end

        it 'allows a change of title' do
          xhr :put, :update, topic_id: @topic.id, slug: @topic.title, title: 'this is a new title for the topic'
          @topic.reload
          @topic.title.should == 'this is a new title for the topic'
        end

        it 'triggers a change of category' do
          Topic.any_instance.expects(:change_category).with('incredible')
          xhr :put, :update, topic_id: @topic.id, slug: @topic.title, category: 'incredible'
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
        lambda { xhr :post, :invite, topic_id: @topic.id }.should raise_error(Discourse::InvalidParameters)
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

end
