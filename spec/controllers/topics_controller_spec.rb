require 'spec_helper'

describe TopicsController do

  context 'wordpress' do
    let!(:user) { log_in(:moderator) }
    let(:p1) { Fabricate(:post, user: user) }
    let(:topic) { p1.topic }
    let!(:p2) { Fabricate(:post, topic: topic, user:user )}

    it "returns the JSON in the format our wordpress plugin needs" do
      xhr :get, :wordpress, topic_id: topic.id, best: 3
      expect(response).to be_success
      json = ::JSON.parse(response.body)
      expect(json).to be_present

      # The JSON has the data the wordpress plugin needs
      expect(json['id']).to eq(topic.id)
      expect(json['posts_count']).to eq(2)
      expect(json['filtered_posts_count']).to eq(2)

      # Posts
      expect(json['posts'].size).to eq(1)
      post = json['posts'][0]
      expect(post['id']).to eq(p2.id)
      expect(post['username']).to eq(user.username)
      expect(post['avatar_template']).to eq("#{Discourse.base_url_no_prefix}#{user.avatar_template}")
      expect(post['name']).to eq(user.name)
      expect(post['created_at']).to be_present
      expect(post['cooked']).to eq(p2.cooked)

      # Participants
      expect(json['participants'].size).to eq(1)
      participant = json['participants'][0]
      expect(participant['id']).to eq(user.id)
      expect(participant['username']).to eq(user.username)
      expect(participant['avatar_template']).to eq("#{Discourse.base_url_no_prefix}#{user.avatar_template}")
    end
  end

  context 'move_posts' do
    it 'needs you to be logged in' do
      expect { xhr :post, :move_posts, topic_id: 111, title: 'blah', post_ids: [1,2,3] }.to raise_error(Discourse::NotLoggedIn)
    end

    describe 'moving to a new topic' do
      let!(:user) { log_in(:moderator) }
      let(:p1) { Fabricate(:post, user: user) }
      let(:topic) { p1.topic }

      it "raises an error without postIds" do
        expect { xhr :post, :move_posts, topic_id: topic.id, title: 'blah' }.to raise_error(ActionController::ParameterMissing)
      end

      it "raises an error when the user doesn't have permission to move the posts" do
        Guardian.any_instance.expects(:can_move_posts?).returns(false)
        xhr :post, :move_posts, topic_id: topic.id, title: 'blah', post_ids: [1,2,3]
        expect(response).to be_forbidden
      end

      context 'success' do
        let(:p2) { Fabricate(:post, user: user) }

        before do
          Topic.any_instance.expects(:move_posts).with(user, [p2.id], title: 'blah', category_id: 123).returns(topic)
          xhr :post, :move_posts, topic_id: topic.id, title: 'blah', post_ids: [p2.id], category_id: 123
        end

        it "returns success" do
          expect(response).to be_success
          result = ::JSON.parse(response.body)
          expect(result['success']).to eq(true)
          expect(result['url']).to be_present
        end
      end

      context 'failure' do
        let(:p2) { Fabricate(:post, user: user) }

        before do
          Topic.any_instance.expects(:move_posts).with(user, [p2.id], title: 'blah').returns(nil)
          xhr :post, :move_posts, topic_id: topic.id, title: 'blah', post_ids: [p2.id]
        end

        it "returns JSON with a false success" do
          expect(response).to be_success
          result = ::JSON.parse(response.body)
          expect(result['success']).to eq(false)
          expect(result['url']).to be_blank
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
          expect(response).to be_success
          result = ::JSON.parse(response.body)
          expect(result['success']).to eq(true)
          expect(result['url']).to be_present
        end
      end

      context 'failure' do
        let(:p2) { Fabricate(:post, user: user) }

        before do
          Topic.any_instance.expects(:move_posts).with(user, [p2.id], destination_topic_id: dest_topic.id).returns(nil)
          xhr :post, :move_posts, topic_id: topic.id, destination_topic_id: dest_topic.id, post_ids: [p2.id]
        end

        it "returns JSON with a false success" do
          expect(response).to be_success
          result = ::JSON.parse(response.body)
          expect(result['success']).to eq(false)
          expect(result['url']).to be_blank
        end
      end
    end
  end

  context "merge_topic" do
    it 'needs you to be logged in' do
      expect { xhr :post, :merge_topic, topic_id: 111, destination_topic_id: 345 }.to raise_error(Discourse::NotLoggedIn)
    end

    describe 'moving to a new topic' do
      let!(:user) { log_in(:moderator) }
      let(:p1) { Fabricate(:post, user: user) }
      let(:topic) { p1.topic }

      it "raises an error without destination_topic_id" do
        expect { xhr :post, :merge_topic, topic_id: topic.id }.to raise_error(ActionController::ParameterMissing)
      end

      it "raises an error when the user doesn't have permission to merge" do
        Guardian.any_instance.expects(:can_move_posts?).returns(false)
        xhr :post, :merge_topic, topic_id: 111, destination_topic_id: 345
        expect(response).to be_forbidden
      end

      let(:dest_topic) { Fabricate(:topic) }

      context 'moves all the posts to the destination topic' do
        let(:p2) { Fabricate(:post, user: user) }

        before do
          Topic.any_instance.expects(:move_posts).with(user, [p1.id], destination_topic_id: dest_topic.id).returns(topic)
          xhr :post, :merge_topic, topic_id: topic.id, destination_topic_id: dest_topic.id
        end

        it "returns success" do
          expect(response).to be_success
          result = ::JSON.parse(response.body)
          expect(result['success']).to eq(true)
          expect(result['url']).to be_present
        end
      end


    end

  end

  context 'change_post_owners' do
    it 'needs you to be logged in' do
      expect { xhr :post, :change_post_owners, topic_id: 111, username: 'user_a', post_ids: [1,2,3] }.to raise_error(Discourse::NotLoggedIn)
    end

    describe 'forbidden to moderators' do
      let!(:moderator) { log_in(:moderator) }
      it 'correctly denies' do
        xhr :post, :change_post_owners, topic_id: 111, username: 'user_a', post_ids: [1,2,3]
        expect(response).to be_forbidden
      end
    end

    describe 'forbidden to trust_level_4s' do
      let!(:trust_level_4) { log_in(:trust_level_4) }

      it 'correctly denies' do
        xhr :post, :change_post_owners, topic_id: 111, username: 'user_a', post_ids: [1,2,3]
        expect(response).to be_forbidden
      end
    end

    describe 'changing ownership' do
      let!(:editor) { log_in(:admin) }
      let(:topic) { Fabricate(:topic) }
      let(:user_a) { Fabricate(:user) }
      let(:p1) { Fabricate(:post, topic_id: topic.id) }
      let(:p2) { Fabricate(:post, topic_id: topic.id) }

      it "raises an error with a parameter missing" do
        expect { xhr :post, :change_post_owners, topic_id: 111, post_ids: [1,2,3] }.to raise_error(ActionController::ParameterMissing)
        expect { xhr :post, :change_post_owners, topic_id: 111, username: 'user_a' }.to raise_error(ActionController::ParameterMissing)
      end

      it "calls PostOwnerChanger" do
        PostOwnerChanger.any_instance.expects(:change_owner!).returns(true)
        xhr :post, :change_post_owners, topic_id: topic.id, username: user_a.username_lower, post_ids: [p1.id]
        expect(response).to be_success
      end

      it "changes multiple posts" do
        # an integration test
        xhr :post, :change_post_owners, topic_id: topic.id, username: user_a.username_lower, post_ids: [p1.id, p2.id]
        p1.reload; p2.reload
        expect(p1.user).not_to eq(nil)
        expect(p1.user).to eq(p2.user)
      end
    end
  end

  context 'similar_to' do

    let(:title) { 'this title is long enough to search for' }
    let(:raw) { 'this body is long enough to search for' }

    it "requires a title" do
      expect { xhr :get, :similar_to, raw: raw }.to raise_error(ActionController::ParameterMissing)
    end

    it "requires a raw body" do
      expect { xhr :get, :similar_to, title: title }.to raise_error(ActionController::ParameterMissing)
    end

    it "raises an error if the title length is below the minimum" do
      SiteSetting.stubs(:min_title_similar_length).returns(100)
      expect { xhr :get, :similar_to, title: title, raw: raw }.to raise_error(Discourse::InvalidParameters)
    end

    it "raises an error if the body length is below the minimum" do
      SiteSetting.stubs(:min_body_similar_length).returns(100)
      expect { xhr :get, :similar_to, title: title, raw: raw }.to raise_error(Discourse::InvalidParameters)
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
      expect { xhr :put, :clear_pin, topic_id: 1 }.to raise_error(Discourse::NotLoggedIn)
    end

    context 'when logged in' do
      let(:topic) { Fabricate(:topic) }
      let!(:user) { log_in }

      it "fails when the user can't see the topic" do
        Guardian.any_instance.expects(:can_see?).with(topic).returns(false)
        xhr :put, :clear_pin, topic_id: topic.id
        expect(response).not_to be_success
      end

      describe 'when the user can see the topic' do
        it "calls clear_pin_for if the user can see the topic" do
          Topic.any_instance.expects(:clear_pin_for).with(user).once
          xhr :put, :clear_pin, topic_id: topic.id
        end

        it "succeeds" do
          xhr :put, :clear_pin, topic_id: topic.id
          expect(response).to be_success
        end
      end

    end

  end

  context 'status' do
    it 'needs you to be logged in' do
      expect { xhr :put, :status, topic_id: 1, status: 'visible', enabled: true }.to raise_error(Discourse::NotLoggedIn)
    end

    describe 'when logged in' do
      before do
        @user = log_in(:moderator)
        @topic = Fabricate(:topic, user: @user)
      end

      it "raises an exception if you can't change it" do
        Guardian.any_instance.expects(:can_moderate?).with(@topic).returns(false)
        xhr :put, :status, topic_id: @topic.id, status: 'visible', enabled: 'true'
        expect(response).to be_forbidden
      end

      it 'requires the status parameter' do
        expect { xhr :put, :status, topic_id: @topic.id, enabled: true }.to raise_error(ActionController::ParameterMissing)
      end

      it 'requires the enabled parameter' do
        expect { xhr :put, :status, topic_id: @topic.id, status: 'visible' }.to raise_error(ActionController::ParameterMissing)
      end

      it 'raises an error with a status not in the whitelist' do
        expect { xhr :put, :status, topic_id: @topic.id, status: 'title', enabled: 'true' }.to raise_error(Discourse::InvalidParameters)
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
      expect { xhr :delete, :destroy_timings, topic_id: 1 }.to raise_error(Discourse::NotLoggedIn)
    end

    context 'when logged in' do
      before do
        @user = log_in
        @topic = Fabricate(:topic, user: @user)
        @topic_user = TopicUser.get(@topic, @topic.user)
      end

      it 'deletes the forum topic user record' do
        PostTiming.expects(:destroy_for).with(@user.id, [@topic.id])
        xhr :delete, :destroy_timings, topic_id: @topic.id
      end

    end

  end


  describe 'mute/unmute' do

    it 'needs you to be logged in' do
      expect { xhr :put, :mute, topic_id: 99}.to raise_error(Discourse::NotLoggedIn)
    end

    it 'needs you to be logged in' do
      expect { xhr :put, :unmute, topic_id: 99}.to raise_error(Discourse::NotLoggedIn)
    end

    describe 'when logged in' do
      before do
        @topic = Fabricate(:topic, user: log_in)
      end

    end

  end

  describe 'recover' do
    it "won't allow us to recover a topic when we're not logged in" do
      expect { xhr :put, :recover, topic_id: 1 }.to raise_error(Discourse::NotLoggedIn)
    end

    describe 'when logged in' do
      let(:topic) { Fabricate(:topic, user: log_in, deleted_at: Time.now, deleted_by: log_in) }

      describe 'without access' do
        it "raises an exception when the user doesn't have permission to delete the topic" do
          Guardian.any_instance.expects(:can_recover_topic?).with(topic).returns(false)
          xhr :put, :recover, topic_id: topic.id
          expect(response).to be_forbidden
        end
      end

      context 'with permission' do
        before do
          Guardian.any_instance.expects(:can_recover_topic?).with(topic).returns(true)
        end

        it 'succeeds' do
          PostDestroyer.any_instance.expects(:recover)
          xhr :put, :recover, topic_id: topic.id
          expect(response).to be_success
        end
      end
    end

  end

  describe 'delete' do
    it "won't allow us to delete a topic when we're not logged in" do
      expect { xhr :delete, :destroy, id: 1 }.to raise_error(Discourse::NotLoggedIn)
    end

    describe 'when logged in' do
      let(:topic) { Fabricate(:topic, user: log_in) }

      describe 'without access' do
        it "raises an exception when the user doesn't have permission to delete the topic" do
          Guardian.any_instance.expects(:can_delete?).with(topic).returns(false)
          xhr :delete, :destroy, id: topic.id
          expect(response).to be_forbidden
        end
      end

      describe 'with permission' do
        before do
          Guardian.any_instance.expects(:can_delete?).with(topic).returns(true)
        end

        it 'succeeds' do
          PostDestroyer.any_instance.expects(:destroy)
          xhr :delete, :destroy, id: topic.id
          expect(response).to be_success
        end

      end

    end
  end

  describe 'id_for_slug' do
    let(:topic) { Fabricate(:post).topic }

    it "returns JSON for the slug" do
      xhr :get, :id_for_slug, slug: topic.slug
      expect(response).to be_success
      json = ::JSON.parse(response.body)
      expect(json).to be_present
      expect(json['topic_id']).to eq(topic.id)
      expect(json['url']).to eq(topic.url)
      expect(json['slug']).to eq(topic.slug)
    end

    it "returns invalid access if the user can't see the topic" do
      Guardian.any_instance.expects(:can_see?).with(topic).returns(false)
      xhr :get, :id_for_slug, slug: topic.slug
      expect(response).not_to be_success
    end
  end

  describe 'show' do

    let(:topic) { Fabricate(:post).topic }
    let!(:p1) { Fabricate(:post, user: topic.user) }
    let!(:p2) { Fabricate(:post, user: topic.user) }

    it 'shows a topic correctly' do
      xhr :get, :show, topic_id: topic.id, slug: topic.slug
      expect(response).to be_success
    end

    it 'return 404 for an invalid page' do
      xhr :get, :show, topic_id: topic.id, slug: topic.slug, page: 2
      expect(response.code).to eq("404")
    end

    it 'can find a topic given a slug in the id param' do
      xhr :get, :show, id: topic.slug
      expect(response).to redirect_to(topic.relative_url)
    end

    it 'keeps the post_number parameter around when redirecting' do
      xhr :get, :show, id: topic.slug, post_number: 42
      expect(response).to redirect_to(topic.relative_url + "/42")
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
      expect { xhr :get, :show, topic_id: topic.id, slug: topic.slug }.to change(TopicViewItem, :count).by(1)
    end

    it 'records incoming links' do
      user = Fabricate(:user)
      get :show, topic_id: topic.id, slug: topic.slug, u: user.username

      expect(IncomingLink.count).to eq(1)
    end

    it 'records redirects' do
      @request.env['HTTP_REFERER'] = 'http://twitter.com'
      get :show, { id: topic.id }

      @request.env['HTTP_REFERER'] = nil
      get :show, topic_id: topic.id, slug: topic.slug

      link = IncomingLink.first
      expect(link.referer).to eq('http://twitter.com')
    end

    it 'tracks a visit for all html requests' do
      current_user = log_in(:coding_horror)
      TopicUser.expects(:track_visit!).with(topic.id, current_user.id)
      get :show, topic_id: topic.id, slug: topic.slug
    end

    context 'consider for a promotion' do
      let!(:user) { log_in(:coding_horror) }
      let(:promotion) do
        result = double
        Promotion.stubs(:new).with(user).returns(result)
        result
      end

      it "reviews the user for a promotion if they're new" do
        user.update_column(:trust_level, TrustLevel[0])
        Promotion.any_instance.expects(:review)
        get :show, topic_id: topic.id, slug: topic.slug
      end
    end

    context 'filters' do

      it 'grabs first page when no filter is provided' do
        TopicView.any_instance.expects(:filter_posts_in_range).with(0, 19)
        xhr :get, :show, topic_id: topic.id, slug: topic.slug
      end

      it 'grabs first page when first page is provided' do
        TopicView.any_instance.expects(:filter_posts_in_range).with(0, 19)
        xhr :get, :show, topic_id: topic.id, slug: topic.slug, page: 1
      end

      it 'grabs correct range when a page number is provided' do
        TopicView.any_instance.expects(:filter_posts_in_range).with(20, 39)
        xhr :get, :show, topic_id: topic.id, slug: topic.slug, page: 2
      end

      it 'delegates a post_number param to TopicView#filter_posts_near' do
        TopicView.any_instance.expects(:filter_posts_near).with(p2.post_number)
        xhr :get, :show, topic_id: topic.id, slug: topic.slug, post_number: p2.post_number
      end
    end

    context "when 'login required' site setting has been enabled" do
      before { SiteSetting.login_required = true }

      context 'and the user is logged in' do
        before { log_in(:coding_horror) }

        it 'shows the topic' do
          get :show, topic_id: topic.id, slug: topic.slug
          expect(response).to be_successful
        end
      end

      context 'and the user is not logged in' do
        let(:api_key) { topic.user.generate_api_key(topic.user) }

        it 'redirects to the login page' do
          get :show, topic_id: topic.id, slug: topic.slug
          expect(response).to redirect_to login_path
        end

        it 'shows the topic if valid api key is provided' do
          get :show, topic_id: topic.id, slug: topic.slug, api_key: api_key.key
          expect(response).to be_successful
          topic.reload
          # free test, only costs a reload
          expect(topic.views).to eq(1)
        end

        it 'returns 403 for an invalid key' do
          get :show, topic_id: topic.id, slug: topic.slug, api_key: "bad"
          expect(response.code.to_i).to be(403)
        end
      end
    end
  end

  describe '#feed' do
    let(:topic) { Fabricate(:post).topic }

    it 'renders rss of the topic' do
      get :feed, topic_id: topic.id, slug: 'foo', format: :rss
      expect(response).to be_success
      expect(response.content_type).to eq('application/rss+xml')
    end
  end

  describe 'update' do
    it "won't allow us to update a topic when we're not logged in" do
      expect { xhr :put, :update, topic_id: 1, slug: 'xyz' }.to raise_error(Discourse::NotLoggedIn)
    end

    describe 'when logged in' do
      before do
        @topic = Fabricate(:topic, user: log_in)
        Fabricate(:post, topic: @topic)
      end

      describe 'without permission' do
        it "raises an exception when the user doesn't have permission to update the topic" do
          Guardian.any_instance.expects(:can_edit?).with(@topic).returns(false)
          xhr :put, :update, topic_id: @topic.id, slug: @topic.title
          expect(response).to be_forbidden
        end
      end

      describe 'with permission' do
        before do
          Guardian.any_instance.expects(:can_edit?).with(@topic).returns(true)
        end

        it 'succeeds' do
          xhr :put, :update, topic_id: @topic.id, slug: @topic.title
          expect(response).to be_success
          expect(::JSON.parse(response.body)['basic_topic']).to be_present
        end

        it 'allows a change of title' do
          xhr :put, :update, topic_id: @topic.id, slug: @topic.title, title: 'This is a new title for the topic'
          @topic.reload
          expect(@topic.title).to eq('This is a new title for the topic')
        end

        it 'triggers a change of category' do
          Topic.any_instance.expects(:change_category_to_id).with(123).returns(true)
          xhr :put, :update, topic_id: @topic.id, slug: @topic.title, category_id: 123
        end

        it 'allows to change category to "uncategorized"' do
          Topic.any_instance.expects(:change_category_to_id).with(0).returns(true)
          xhr :put, :update, topic_id: @topic.id, slug: @topic.title, category_id: ""
        end

        it "returns errors with invalid titles" do
          xhr :put, :update, topic_id: @topic.id, slug: @topic.title, title: 'asdf'
          expect(response).not_to be_success
        end

        it "returns errors when the rate limit is exceeded" do
          EditRateLimiter.any_instance.expects(:performed!).raises(RateLimiter::LimitExceeded.new(60))
          xhr :put, :update, topic_id: @topic.id, slug: @topic.title, title: 'This is a new title for the topic'
          expect(response).not_to be_success
        end

        it "returns errors with invalid categories" do
          Topic.any_instance.expects(:change_category_to_id).returns(false)
          xhr :put, :update, topic_id: @topic.id, slug: @topic.title, category_id: -1
          expect(response).not_to be_success
        end

        it "doesn't call the PostRevisor when there is no changes" do
          PostRevisor.any_instance.expects(:revise!).never
          xhr :put, :update, topic_id: @topic.id, slug: @topic.title, title: @topic.title, category_id: @topic.category_id
          expect(response).to be_success
        end

        context 'when topic is private' do
          before do
            @topic.archetype = Archetype.private_message
            @topic.category = nil
            @topic.save!
          end

          context 'when there are no changes' do
            it 'does not call the PostRevisor' do
              PostRevisor.any_instance.expects(:revise!).never
              xhr :put, :update, topic_id: @topic.id, slug: @topic.title, title: @topic.title, category_id: nil
              expect(response).to be_success
            end
          end
        end

        context "allow_uncategorized_topics is false" do
          before do
            SiteSetting.stubs(:allow_uncategorized_topics).returns(false)
          end

          it "can add a category to an uncategorized topic" do
            Topic.any_instance.expects(:change_category_to_id).with(456).returns(true)
            xhr :put, :update, topic_id: @topic.id, slug: @topic.title, category_id: 456
            expect(response).to be_success
          end
        end

      end
    end
  end

  describe 'invite' do

    describe "group invites" do
      it "works correctly" do
        group = Fabricate(:group)
        topic = Fabricate(:topic)
        _admin = log_in(:admin)

        xhr :post, :invite, topic_id: topic.id, email: 'hiro@from.heros', group_ids: "#{group.id}"

        expect(response).to be_success

        invite = Invite.find_by(email: 'hiro@from.heros')
        groups = invite.groups.to_a
        expect(groups.count).to eq(1)
        expect(groups[0].id).to eq(group.id)
      end
    end

    it "won't allow us to invite toa topic when we're not logged in" do
      expect { xhr :post, :invite, topic_id: 1, email: 'jake@adventuretime.ooo' }.to raise_error(Discourse::NotLoggedIn)
    end

    describe 'when logged in as group manager' do
      let(:group_manager) { log_in }
      let(:group) { Fabricate(:group).tap { |g| g.add(group_manager); g.appoint_manager(group_manager) } }
      let(:private_category)  { Fabricate(:private_category, group: group) }
      let(:group_private_topic) { Fabricate(:topic, category: private_category, user: group_manager) }
      let(:recipient) { 'jake@adventuretime.ooo' }

      it "should attach group to the invite" do
        xhr :post, :invite, topic_id: group_private_topic.id, user: recipient
        expect(response).to be_success
        expect(Invite.find_by(email: recipient).groups).to eq([group])
      end
    end

    describe 'when logged in' do
      before do
        @topic = Fabricate(:topic, user: log_in)
      end

      it 'requires an email parameter' do
        expect { xhr :post, :invite, topic_id: @topic.id }.to raise_error(ActionController::ParameterMissing)
      end

      describe 'without permission' do
        it "raises an exception when the user doesn't have permission to invite to the topic" do
          xhr :post, :invite, topic_id: @topic.id, user: 'jake@adventuretime.ooo'
          expect(response).to be_forbidden
        end
      end

      describe 'with admin permission' do

        let!(:admin) do
          log_in :admin
        end

        it 'should work as expected' do
          xhr :post, :invite, topic_id: @topic.id, user: 'jake@adventuretime.ooo'
          expect(response).to be_success
          expect(::JSON.parse(response.body)).to eq({'success' => 'OK'})
          expect(Invite.where(invited_by_id: admin.id).count).to eq(1)
        end

        it 'should fail on shoddy email' do
          xhr :post, :invite, topic_id: @topic.id, user: 'i_am_not_an_email'
          expect(response).not_to be_success
          expect(::JSON.parse(response.body)).to eq({'failed' => 'FAILED'})
        end

      end

    end

  end

  describe 'autoclose' do

    it 'needs you to be logged in' do
      expect {
        xhr :put, :autoclose, topic_id: 99, auto_close_time: '24', auto_close_based_on_last_post: false
      }.to raise_error(Discourse::NotLoggedIn)
    end

    it 'needs you to be an admin or mod' do
      log_in
      xhr :put, :autoclose, topic_id: 99, auto_close_time: '24', auto_close_based_on_last_post: false
      expect(response).to be_forbidden
    end

    describe 'when logged in' do
      before do
        @admin = log_in(:admin)
        @topic = Fabricate(:topic, user: @admin)
      end

      it "can set a topic's auto close time and 'based on last post' property" do
        Topic.any_instance.expects(:set_auto_close).with("24", @admin)
        xhr :put, :autoclose, topic_id: @topic.id, auto_close_time: '24', auto_close_based_on_last_post: true
        json = ::JSON.parse(response.body)
        expect(json).to have_key('auto_close_at')
        expect(json).to have_key('auto_close_hours')
      end

      it "can remove a topic's auto close time" do
        Topic.any_instance.expects(:set_auto_close).with(nil, anything)
        xhr :put, :autoclose, topic_id: @topic.id, auto_close_time: nil, auto_close_based_on_last_post: false
      end
    end

  end

  describe 'make_banner' do

    it 'needs you to be a staff member' do
      log_in
      xhr :put, :make_banner, topic_id: 99
      expect(response).to be_forbidden
    end

    describe 'when logged in' do

      it "changes the topic archetype to 'banner'" do
        topic = Fabricate(:topic, user: log_in(:admin))
        Topic.any_instance.expects(:make_banner!)

        xhr :put, :make_banner, topic_id: topic.id
        expect(response).to be_success
      end

    end

  end

  describe 'remove_banner' do

    it 'needs you to be a staff member' do
      log_in
      xhr :put, :remove_banner, topic_id: 99
      expect(response).to be_forbidden
    end

    describe 'when logged in' do

      it "resets the topic archetype" do
        topic = Fabricate(:topic, user: log_in(:admin))
        Topic.any_instance.expects(:remove_banner!)

        xhr :put, :remove_banner, topic_id: topic.id
        expect(response).to be_success
      end

    end

  end

  describe "bulk" do
    it 'needs you to be logged in' do
      expect { xhr :put, :bulk }.to raise_error(Discourse::NotLoggedIn)
    end

    describe "when logged in" do
      let!(:user) { log_in }
      let(:operation) { {type: 'change_category', category_id: '1'} }
      let(:topic_ids) { [1,2,3] }

      it "requires a list of topic_ids or filter" do
        expect { xhr :put, :bulk, operation: operation }.to raise_error(ActionController::ParameterMissing)
      end

      it "requires an operation param" do
        expect { xhr :put, :bulk, topic_ids: topic_ids}.to raise_error(ActionController::ParameterMissing)
      end

      it "requires a type field for the operation param" do
        expect { xhr :put, :bulk, topic_ids: topic_ids, operation: {}}.to raise_error(ActionController::ParameterMissing)
      end

      it "delegates work to `TopicsBulkAction`" do
        topics_bulk_action = mock
        TopicsBulkAction.expects(:new).with(user, topic_ids, operation).returns(topics_bulk_action)
        topics_bulk_action.expects(:perform!)
        xhr :put, :bulk, topic_ids: topic_ids, operation: operation
      end
    end
  end

  describe 'remove_bookmarks' do
    it "should remove bookmarks properly from non first post" do
      bookmark = PostActionType.types[:bookmark]
      user = log_in

      post = create_post
      post2 = create_post(topic_id: post.topic_id)

      PostAction.act(user, post2, bookmark)

      xhr :put, :bookmark, topic_id: post.topic_id
      PostAction.where(user_id: user.id, post_action_type: bookmark).count.should == 2

      xhr :put, :remove_bookmarks, topic_id: post.topic_id
      PostAction.where(user_id: user.id, post_action_type: bookmark).count.should == 0

    end
  end


  describe 'reset_new' do
    it 'needs you to be logged in' do
      expect { xhr :put, :reset_new }.to raise_error(Discourse::NotLoggedIn)
    end

    let(:user) { log_in(:user) }

    it "updates the `new_since` date" do
      old_date = 2.years.ago

      user.user_stat.update_column(:new_since, old_date)

      xhr :put, :reset_new
      user.reload
      expect(user.user_stat.new_since.to_date).not_to eq(old_date.to_date)

    end

  end
end
