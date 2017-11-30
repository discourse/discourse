require 'rails_helper'

shared_examples 'finding and showing post' do
  let(:user) { log_in }
  let(:post) { Fabricate(:post, user: user) }

  it 'ensures the user can see the post' do
    Guardian.any_instance.expects(:can_see?).with(post).returns(false)
    get action, params: params, format: :json
    expect(response).to be_forbidden
  end

  it 'succeeds' do
    get action, params: params, format: :json
    expect(response).to be_success
  end

  context "deleted post" do
    before do
      post.trash!(user)
    end

    it "can't find deleted posts as an anonymous user" do
      get action, params: params, format: :json
      expect(response.status).to eq(404)
    end

    it "can't find deleted posts as a regular user" do
      log_in(:user)
      get action, params: params, format: :json
      expect(response.status).to eq(404)
    end

    it "can find posts as a moderator" do
      log_in(:moderator)
      get action, params: params, format: :json
      expect(response).to be_success
    end

    it "can find posts as a admin" do
      log_in(:admin)
      get action, params: params, format: :json
      expect(response).to be_success
    end
  end
end

shared_examples 'action requires login' do |method, action, params|
  it 'raises an exception when not logged in' do
    expect do
      options = { format: :json }
      options.merge!(params: params) if params
      self.public_send(method, action, options)
    end.to raise_error(Discourse::NotLoggedIn)
  end
end

describe PostsController do

  describe 'latest' do
    let(:user) { log_in }
    let!(:public_topic) { Fabricate(:topic) }
    let!(:post) { Fabricate(:post, user: user, topic: public_topic) }
    let!(:private_topic) { Fabricate(:topic, archetype: Archetype.private_message, category: nil) }
    let!(:private_post) { Fabricate(:post, user: user, topic: private_topic) }
    let!(:topicless_post) { Fabricate(:post, user: user, raw: '<p>Car 54, where are you?</p>') }

    context "public posts" do
      before do
        topicless_post.update topic_id: -100
      end

      it 'returns public posts with topic for json' do
        get :latest, params: { id: "latest_posts" }, format: :json
        expect(response).to be_success
        json = ::JSON.parse(response.body)
        post_ids = json['latest_posts'].map { |p| p['id'] }
        expect(post_ids).to include post.id
        expect(post_ids).to_not include private_post.id
        expect(post_ids).to_not include topicless_post.id
      end
    end

    context 'private posts' do
      before do
        Guardian.any_instance.expects(:can_see?).with(private_post).returns(true)
      end

      it 'returns private posts for json' do
        get :latest, params: { id: "private_posts" }, format: :json
        expect(response).to be_success
        json = ::JSON.parse(response.body)
        post_ids = json['private_posts'].map { |p| p['id'] }
        expect(post_ids).to include private_post.id
        expect(post_ids).to_not include post.id
      end
    end
  end

  describe 'cooked' do
    before do
      post = Post.new(cooked: 'wat')
      PostsController.any_instance.expects(:find_post_from_params).returns(post)
    end

    it 'returns the cooked conent' do
      get :cooked, params: { id: 1234 }, format: :json
      expect(response).to be_success
      json = ::JSON.parse(response.body)
      expect(json).to be_present
      expect(json['cooked']).to eq('wat')
    end
  end

  describe 'raw_email' do
    include_examples "action requires login", :get, :raw_email, id: 2

    describe "when logged in" do
      let(:user) { log_in }
      let(:post) { Fabricate(:post, deleted_at: 2.hours.ago, user: user, raw_email: 'email_content') }

      it "raises an error if the user doesn't have permission to view raw email" do
        Guardian.any_instance.expects(:can_view_raw_email?).returns(false)

        get :raw_email, params: { id: post.id }, format: :json

        expect(response).to be_forbidden
      end

      it "can view raw email" do
        Guardian.any_instance.expects(:can_view_raw_email?).returns(true)

        get :raw_email, params: { id: post.id }, format: :json

        expect(response).to be_success
        json = ::JSON.parse(response.body)
        expect(json['raw_email']).to eq('email_content')
      end

    end

  end

  describe 'show' do
    include_examples 'finding and showing post' do
      let(:action) { :show }
      let(:params) { { id: post.id } }
    end

    it 'gets all the expected fields' do
      # non fabricated test
      new_post = create_post
      get :show, params: { id: new_post.id }, format: :json
      parsed = JSON.parse(response.body)
      expect(parsed["topic_slug"]).to eq(new_post.topic.slug)
      expect(parsed["moderator"]).to eq(false)
      expect(parsed["username"]).to eq(new_post.user.username)
      expect(parsed["cooked"]).to eq(new_post.cooked)
    end
  end

  describe 'by_number' do
    include_examples 'finding and showing post' do
      let(:action) { :by_number }
      let(:params) { { topic_id: post.topic_id, post_number: post.post_number } }
    end
  end

  describe 'reply_history' do
    include_examples 'finding and showing post' do
      let(:action) { :reply_history }
      let(:params) { { id: post.id } }
    end

    it 'asks post for reply history' do
      Post.any_instance.expects(:reply_history)
      get :reply_history, params: { id: post.id }, format: :json
    end
  end

  describe 'replies' do
    include_examples 'finding and showing post' do
      let(:action) { :replies }
      let(:params) { { post_id: post.id } }
    end

    it 'asks post for replies' do
      p1 = Fabricate(:post)
      get :replies, params: { post_id: p1.id }, format: :json
      expect(response.status).to eq(200)
    end
  end

  describe 'delete a post' do
    include_examples 'action requires login', :delete, :destroy, id: 123

    describe 'when logged in' do

      let(:user) { log_in(:moderator) }
      let(:post) { Fabricate(:post, user: user, post_number: 2) }

      it 'does not allow to destroy when edit time limit expired' do
        Guardian.any_instance.stubs(:can_delete_post?).with(post).returns(false)
        Post.any_instance.stubs(:edit_time_limit_expired?).returns(true)

        delete :destroy, params: { id: post.id }, format: :json

        expect(response.status).to eq(422)
        expect(JSON.parse(response.body)['errors']).to include(I18n.t('too_late_to_edit'))
      end

      it "raises an error when the user doesn't have permission to see the post" do
        Guardian.any_instance.expects(:can_delete?).with(post).returns(false)
        delete :destroy, params: { id: post.id }, format: :json
        expect(response).to be_forbidden
      end

      it "uses a PostDestroyer" do
        destroyer = mock
        PostDestroyer.expects(:new).returns(destroyer)
        destroyer.expects(:destroy)
        delete :destroy, params: { id: post.id }, format: :json
      end

    end
  end

  describe 'recover a post' do
    include_examples 'action requires login', :put, :recover, post_id: 123

    describe 'when logged in' do

      let(:user) { log_in(:moderator) }
      let(:post) { Fabricate(:post, user: user, post_number: 2) }

      it "raises an error when the user doesn't have permission to see the post" do
        Guardian.any_instance.expects(:can_recover_post?).with(post).returns(false)
        put :recover, params: { post_id: post.id }, format: :json
        expect(response).to be_forbidden
      end

      it "recovers a post correctly" do
        topic_id = create_post.topic_id
        post = create_post(topic_id: topic_id)

        PostDestroyer.new(user, post).destroy
        put :recover, params: { post_id: post.id }, format: :json
        post.reload
        expect(post.deleted_at).to eq(nil)
      end

    end
  end

  describe 'destroy_many' do
    include_examples 'action requires login', :delete, :destroy_many, post_ids: [123, 345]

    describe 'when logged in' do

      let!(:poster) { log_in(:moderator) }
      let!(:post1) { Fabricate(:post, user: poster, post_number: 2) }
      let!(:post2) { Fabricate(:post, topic_id: post1.topic_id, user: poster, post_number: 3, reply_to_post_number: post1.post_number) }

      it "raises invalid parameters no post_ids" do
        expect do
          delete :destroy_many, format: :json
        end.to raise_error(ActionController::ParameterMissing)
      end

      it "raises invalid parameters with missing ids" do
        expect do
          delete :destroy_many, params: { post_ids: [12345] }, format: :json
        end.to raise_error(Discourse::InvalidParameters)
      end

      it "raises an error when the user doesn't have permission to delete the posts" do
        Guardian.any_instance.expects(:can_delete?).with(instance_of(Post)).returns(false)
        delete :destroy_many, params: { post_ids: [post1.id, post2.id] }, format: :json
        expect(response).to be_forbidden
      end

      it "deletes the post" do
        PostDestroyer.any_instance.expects(:destroy).twice
        delete :destroy_many, params: { post_ids: [post1.id, post2.id] }, format: :json
      end

      it "updates the highest read data for the forum" do
        Topic.expects(:reset_highest).twice
        delete :destroy_many, params: { post_ids: [post1.id, post2.id] }, format: :json
      end

      describe "can delete replies" do

        before do
          PostReply.create(post_id: post1.id, reply_id: post2.id)
        end

        it "deletes the post and the reply to it" do
          PostDestroyer.any_instance.expects(:destroy).twice
          delete :destroy_many,
            params: { post_ids: [post1.id], reply_post_ids: [post1.id] },
            format: :json
        end

      end

    end

  end

  describe 'edit a post' do

    include_examples 'action requires login', :put, :update, id: 2

    let(:post) { Fabricate(:post, user: logged_in_as) }
    let(:update_params) do
      {
        id: post.id,
        post: { raw: 'edited body', edit_reason: 'typo' },
        image_sizes: { 'http://image.com/image.jpg' => { 'width' => 123, 'height' => 456 } },
      }
    end
    let(:moderator) { Fabricate(:moderator) }

    describe 'when logged in as a regular user' do
      let(:logged_in_as) { log_in }

      it 'does not allow to update when edit time limit expired' do
        Guardian.any_instance.stubs(:can_edit?).with(post).returns(false)
        Post.any_instance.stubs(:edit_time_limit_expired?).returns(true)

        put :update, params: update_params, format: :json

        expect(response.status).to eq(422)
        expect(JSON.parse(response.body)['errors']).to include(I18n.t('too_late_to_edit'))
      end

      it 'passes the image sizes through' do
        Post.any_instance.expects(:image_sizes=)
        put :update, params: update_params, format: :json
      end

      it 'passes the edit reason through' do
        Post.any_instance.expects(:edit_reason=)
        put :update, params: update_params, format: :json
      end

      it "raises an error when the post parameter is missing" do
        update_params.delete(:post)
        expect {
          put :update, params: update_params, format: :json
        }.to raise_error(ActionController::ParameterMissing)
      end

      it "raises an error when the user doesn't have permission to see the post" do
        Guardian.any_instance.expects(:can_edit?).with(post).at_least_once.returns(false)
        put :update, params: update_params, format: :json
        expect(response).to be_forbidden
      end

      it "calls revise with valid parameters" do
        PostRevisor.any_instance.expects(:revise!).with(post.user, { raw: 'edited body' , edit_reason: 'typo' }, anything)
        put :update, params: update_params, format: :json
      end

      it "extracts links from the new body" do
        param = update_params
        param[:post][:raw] = 'I just visited this https://google.com so many cool links'

        put :update, params: param, format: :json

        expect(response).to be_success
        expect(TopicLink.count).to eq(1)
      end

      it "doesn't allow updating of deleted posts" do
        first_post = post.topic.ordered_posts.first
        PostDestroyer.new(moderator, first_post).destroy

        put :update, params: update_params, format: :json
        expect(response).not_to be_success
      end
    end

    describe "when logged in as staff" do
      let(:logged_in_as) { log_in(:moderator) }

      it "supports updating posts in deleted topics" do
        first_post = post.topic.ordered_posts.first
        PostDestroyer.new(moderator, first_post).destroy

        put :update, params: update_params, format: :json
        expect(response).to be_success

        post.reload
        expect(post.raw).to eq('edited body')
      end
    end

  end

  describe 'bookmark a post' do

    include_examples 'action requires login', :put, :bookmark, post_id: 2

    describe 'when logged in' do
      let(:user) { log_in }
      let(:post) { Fabricate(:post, user: user) }
      let(:private_message) { Fabricate(:private_message_post) }

      it "raises an error if the user doesn't have permission to see the post" do
        post

        put :bookmark,
          params: { post_id: private_message.id, bookmarked: 'true' },
          format: :json

        expect(response).to be_forbidden
      end

      it 'creates a bookmark' do
        put :bookmark,
          params: { post_id: post.id, bookmarked: 'true' },
          format: :json

        post_action = PostAction.find_by(user: user, post: post)

        expect(post_action.post_action_type_id).to eq(PostActionType.types[:bookmark])
      end

      context "removing a bookmark" do
        let(:post_action) { PostAction.act(user, post, PostActionType.types[:bookmark]) }
        let(:admin) { Fabricate(:admin) }

        it "returns the right response when post is not bookmarked" do
          put :bookmark,
            params: { post_id: Fabricate(:post, user: user).id },
            format: :json

          expect(response.status).to eq(404)
        end

        it 'should be able to remove a bookmark' do
          post_action
          put :bookmark, params: { post_id: post.id }, format: :json

          expect(PostAction.find_by(id: post_action.id)).to eq(nil)
        end

        describe "when user doesn't have permission to see bookmarked post" do
          it "should still be able to remove a bookmark" do
            post_action
            post = post_action.post
            topic = post.topic
            topic.convert_to_private_message(admin)
            topic.remove_allowed_user(admin, user.username)

            expect(Guardian.new(user).can_see_post?(post.reload)).to eq(false)

            put :bookmark, params: { post_id: post.id }, format: :json

            expect(PostAction.find_by(id: post_action.id)).to eq(nil)
          end
        end

        describe "when post has been deleted" do
          it "should still be able to remove a bookmark" do
            post = post_action.post
            post.trash!

            put :bookmark, params: { post_id: post.id }, format: :json

            expect(PostAction.find_by(id: post_action.id)).to eq(nil)
          end
        end
      end

    end

  end

  describe "wiki" do

    include_examples "action requires login", :put, :wiki, post_id: 2

    describe "when logged in" do
      let(:user) { log_in }
      let(:post) { Fabricate(:post, user: user) }

      it "raises an error if the user doesn't have permission to wiki the post" do
        Guardian.any_instance.expects(:can_wiki?).with(post).returns(false)

        put :wiki,
          params: { post_id: post.id, wiki: 'true' },
          format: :json

        expect(response).to be_forbidden
      end

      it "toggle wiki status should create a new version" do
        _admin = log_in(:admin)
        another_user = Fabricate(:user)
        another_post = Fabricate(:post, user: another_user)

        expect do
          put :wiki,
            params: { post_id: another_post.id, wiki: 'true' },
            format: :json
        end.to change { another_post.reload.version }.by(1)

        expect do
          put :wiki,
            params: { post_id: another_post.id, wiki: 'false' },
            format: :json
        end.to change { another_post.reload.version }.by(-1)

        _another_admin = log_in(:admin)

        expect do
          put :wiki,
            params: { post_id: another_post.id, wiki: 'true' },
            format: :json
        end.to change { another_post.reload.version }.by(1)
      end

      it "can wiki a post" do
        Guardian.any_instance.expects(:can_wiki?).with(post).returns(true)

        put :wiki, params: { post_id: post.id, wiki: 'true' }, format: :json

        post.reload
        expect(post.wiki).to eq(true)
      end

      it "can unwiki a post" do
        wikied_post = Fabricate(:post, user: user, wiki: true)
        Guardian.any_instance.expects(:can_wiki?).with(wikied_post).returns(true)

        put :wiki, params: { post_id: wikied_post.id, wiki: 'false' }, format: :json

        wikied_post.reload
        expect(wikied_post.wiki).to eq(false)
      end

    end

  end

  describe "post_type" do

    include_examples "action requires login", :put, :post_type, post_id: 2

    describe "when logged in" do
      let(:user) { log_in }
      let(:post) { Fabricate(:post, user: user) }

      it "raises an error if the user doesn't have permission to change the post type" do
        Guardian.any_instance.expects(:can_change_post_type?).returns(false)

        put :post_type, params: { post_id: post.id, post_type: 2 }, format: :json

        expect(response).to be_forbidden
      end

      it "can change the post type" do
        Guardian.any_instance.expects(:can_change_post_type?).returns(true)

        put :post_type, params: { post_id: post.id, post_type: 2 }, format: :json

        post.reload
        expect(post.post_type).to eq(2)
      end

    end

  end

  describe "rebake" do

    include_examples "action requires login", :put, :rebake, post_id: 2

    describe "when logged in" do
      let(:user) { log_in }
      let(:post) { Fabricate(:post, user: user) }

      it "raises an error if the user doesn't have permission to rebake the post" do
        Guardian.any_instance.expects(:can_rebake?).returns(false)

        put :rebake, params: { post_id: post.id }, format: :json

        expect(response).to be_forbidden
      end

      it "can rebake the post" do
        Guardian.any_instance.expects(:can_rebake?).returns(true)

        put :rebake, params: { post_id: post.id }, format: :json

        expect(response).to be_success
      end

    end

  end

  describe 'creating a post' do

    before do
      SiteSetting.min_first_post_typing_time = 0
    end

    include_examples 'action requires login', :post, :create

    context 'api' do
      it 'memoizes duplicate requests' do
        raw = "this is a test post 123 #{SecureRandom.hash}"
        title = "this is a title #{SecureRandom.hash}"

        user = Fabricate(:user)
        master_key = ApiKey.create_master_key.key

        post :create, params: {
          api_username: user.username,
          api_key: master_key,
          raw: raw,
          title: title,
          wpid: 1
        }, format: :json

        expect(response).to be_success
        original = response.body

        post :create, params: {
          api_username: user.username_lower,
          api_key: master_key,
          raw: raw,
          title: title,
          wpid: 2
        }, format: :json

        expect(response).to be_success
        expect(response.body).to eq(original)
      end

      it 'allows to create posts in import_mode' do
        NotificationEmailer.enable
        post_1 = Fabricate(:post)
        user = Fabricate(:user)
        master_key = ApiKey.create_master_key.key

        post :create, params: {
          api_username: user.username,
          api_key: master_key,
          raw: 'this is test reply 1',
          topic_id: post_1.topic.id,
          reply_to_post_number: 1
        }, format: :json

        expect(response).to be_success
        expect(post_1.topic.user.notifications.count).to eq(1)
        post_1.topic.user.notifications.destroy_all

        post :create, params: {
          api_username: user.username,
          api_key: master_key,
          raw: 'this is test reply 2',
          topic_id: post_1.topic.id,
          reply_to_post_number: 1,
          import_mode: true
        }, format: :json

        expect(response).to be_success
        expect(post_1.topic.user.notifications.count).to eq(0)

        post :create, params: {
          api_username: user.username,
          api_key: master_key,
          raw: 'this is test reply 3',
          topic_id: post_1.topic.id,
          reply_to_post_number: 1,
          import_mode: false
        }

        expect(response).to be_success
        expect(post_1.topic.user.notifications.count).to eq(1)
      end
    end

    describe 'when logged in' do

      let!(:user) { log_in }
      let(:moderator) { log_in(:moderator) }
      let(:new_post) { Fabricate.build(:post, user: user) }

      context "fast typing" do
        before do
          SiteSetting.min_first_post_typing_time = 3000
          SiteSetting.auto_silence_fast_typers_max_trust_level = 1
        end

        it 'queues the post if min_first_post_typing_time is not met' do
          post :create, params: {
            raw: 'this is the test content',
            title: 'this is the test title for the topic'
          }, format: :json

          expect(response).to be_success
          parsed = ::JSON.parse(response.body)

          expect(parsed["action"]).to eq("enqueued")

          user.reload
          expect(user).to be_silenced

          qp = QueuedPost.first

          mod = Fabricate(:moderator)
          qp.approve!(mod)

          user.reload
          expect(user).not_to be_silenced
        end

        it "doesn't enqueue replies when the topic is closed" do
          topic = Fabricate(:closed_topic)

          post :create, params: {
            raw: 'this is the test content',
            title: 'this is the test title for the topic',
            topic_id: topic.id
          }, format: :json

          expect(response).not_to be_success
          parsed = ::JSON.parse(response.body)
          expect(parsed["action"]).not_to eq("enqueued")
        end

        it "doesn't enqueue replies when the post is too long" do
          SiteSetting.max_post_length = 10

          post :create, params: {
            raw: 'this is the test content',
            title: 'this is the test title for the topic'
          }, format: :json

          expect(response).not_to be_success
          parsed = ::JSON.parse(response.body)
          expect(parsed["action"]).not_to eq("enqueued")
        end
      end

      it 'silences correctly based on auto_silence_first_post_regex' do
        SiteSetting.auto_silence_first_post_regex = "I love candy|i eat s[1-5]"

        post :create, params: {
          raw: 'this is the test content',
          title: 'when I eat s3 sometimes when not looking'
        }, format: :json

        expect(response).to be_success
        parsed = ::JSON.parse(response.body)

        expect(parsed["action"]).to eq("enqueued")

        user.reload
        expect(user).to be_silenced
      end

      it "can send a message to a group" do

        group = Group.create(name: 'test_group', messageable_level: Group::ALIAS_LEVELS[:nobody])
        user1 = Fabricate(:user)
        group.add(user1)

        post :create, params: {
          raw: 'I can haz a test',
          title: 'I loves my test',
          target_usernames: group.name,
          archetype: Archetype.private_message
        }, format: :json

        expect(response).not_to be_success

        # allow pm to this group
        group.update_columns(messageable_level: Group::ALIAS_LEVELS[:everyone])

        post :create, params: {
          raw: 'I can haz a test',
          title: 'I loves my test',
          target_usernames: group.name,
          archetype: Archetype.private_message
        }, format: :json

        expect(response).to be_success

        parsed = ::JSON.parse(response.body)
        post = Post.find(parsed['id'])

        expect(post.topic.topic_allowed_users.length).to eq(1)
        expect(post.topic.topic_allowed_groups.length).to eq(1)
      end

      it "returns the nested post with a param" do
        post :create, params: {
          raw: 'this is the test content',
          title: 'this is the test title for the topic',
          nested_post: true
        }, format: :json

        expect(response).to be_success
        parsed = ::JSON.parse(response.body)
        expect(parsed['post']).to be_present
        expect(parsed['post']['cooked']).to be_present
      end

      it 'protects against dupes' do
        raw = "this is a test post 123 #{SecureRandom.hash}"
        title = "this is a title #{SecureRandom.hash}"

        post :create, params: { raw: raw, title: title, wpid: 1 }, format: :json
        expect(response).to be_success

        post :create, params: { raw: raw, title: title, wpid: 2 }, format: :json
        expect(response).not_to be_success
      end

      context "errors" do

        let(:post_with_errors) { Fabricate.build(:post, user: user) }

        before do
          post_with_errors.errors.add(:base, I18n.t(:spamming_host))
          PostCreator.any_instance.stubs(:errors).returns(post_with_errors.errors)
          PostCreator.any_instance.expects(:create).returns(post_with_errors)
        end

        it "does not succeed" do
          post :create, params: { raw: 'test' }, format: :json
          User.any_instance.expects(:flag_linked_posts_as_spam).never
          expect(response).not_to be_success
        end

        it "it triggers flag_linked_posts_as_spam when the post creator returns spam" do
          PostCreator.any_instance.expects(:spam?).returns(true)
          User.any_instance.expects(:flag_linked_posts_as_spam)
          post :create, params: { raw: 'test' }, format: :json
        end
      end
    end
  end

  describe "revisions" do

    let(:post) { Fabricate(:post, version: 2) }
    let(:post_revision) { Fabricate(:post_revision, post: post) }

    it "throws an exception when revision is < 2" do
      expect {
        get :revisions, params: {
          post_id: post_revision.post_id, revision: 1
        }, format: :json
      }.to raise_error(Discourse::InvalidParameters)
    end

    context "when edit history is not visible to the public" do

      before { SiteSetting.edit_history_visible_to_public = false }

      it "ensures anonymous cannot see the revisions" do
        get :revisions, params: {
          post_id: post_revision.post_id, revision: post_revision.number
        }, format: :json

        expect(response).to be_forbidden
      end

      it "ensures regular user cannot see the revisions" do
        log_in(:user)
        get :revisions, params: {
          post_id: post_revision.post_id, revision: post_revision.number
        }, format: :json
        expect(response).to be_forbidden
      end

      it "ensures staff can see the revisions" do
        log_in(:admin)
        get :revisions, params: {
          post_id: post_revision.post_id, revision: post_revision.number
        }, format: :json
        expect(response).to be_success
      end

      it "ensures poster can see the revisions" do
        user = log_in(:active_user)
        post = Fabricate(:post, user: user, version: 3)
        pr = Fabricate(:post_revision, user: user, post: post)
        get :revisions, params: {
          post_id: pr.post_id, revision: pr.number
        }, format: :json
        expect(response).to be_success
      end

      it "ensures trust level 4 can see the revisions" do
        log_in(:trust_level_4)
        get :revisions, params: {
          post_id: post_revision.post_id, revision: post_revision.number
        }, format: :json
        expect(response).to be_success
      end

    end

    context "when edit history is visible to everyone" do

      before { SiteSetting.edit_history_visible_to_public = true }

      it "ensures anyone can see the revisions" do
        get :revisions, params: {
          post_id: post_revision.post_id, revision: post_revision.number
        }, format: :json
        expect(response).to be_success
      end

    end

    context "deleted post" do
      let(:admin) { log_in(:admin) }
      let(:deleted_post) { Fabricate(:post, user: admin, version: 3) }
      let(:deleted_post_revision) { Fabricate(:post_revision, user: admin, post: deleted_post) }

      before { deleted_post.trash!(admin) }

      it "also work on deleted post" do
        get :revisions, params: {
          post_id: deleted_post_revision.post_id, revision: deleted_post_revision.number
        }, format: :json
        expect(response).to be_success
      end
    end

    context "deleted topic" do
      let(:admin) { log_in(:admin) }
      let(:deleted_topic) { Fabricate(:topic, user: admin) }
      let(:post) { Fabricate(:post, user: admin, topic: deleted_topic, version: 3) }
      let(:post_revision) { Fabricate(:post_revision, user: admin, post: post) }

      before { deleted_topic.trash!(admin) }

      it "also work on deleted topic" do
        get :revisions, params: {
          post_id: post_revision.post_id, revision: post_revision.number
        }
        expect(response).to be_success
      end
    end

  end

  describe 'revert post to a specific revision' do
    include_examples 'action requires login', :put, :revert, post_id: 123, revision: 2

    let(:post) { Fabricate(:post, user: logged_in_as, raw: "Lorem ipsum dolor sit amet, cu nam libris tractatos, ancillae senserit ius ex") }
    let(:post_revision) { Fabricate(:post_revision, post: post, modifications: { "raw" => ["this is original post body.", "this is edited post body."] }) }
    let(:blank_post_revision) { Fabricate(:post_revision, post: post, modifications: { "edit_reason" => ["edit reason #1", "edit reason #2"] }) }
    let(:same_post_revision) { Fabricate(:post_revision, post: post, modifications: { "raw" => ["Lorem ipsum dolor sit amet, cu nam libris tractatos, ancillae senserit ius ex", "this is edited post body."] }) }

    let(:revert_params) do
      {
        post_id: post.id,
        revision: post_revision.number
      }
    end
    let(:moderator) { Fabricate(:moderator) }

    describe 'when logged in as a regular user' do
      let(:logged_in_as) { log_in }

      it "does not work" do
        put :revert, params: revert_params, format: :json
        expect(response).to_not be_success
      end
    end

    describe "when logged in as staff" do
      let(:logged_in_as) { log_in(:moderator) }

      it "throws an exception when revision is < 2" do
        expect {
          put :revert, params:  { post_id: post.id, revision: 1 }, format: :json
        }.to raise_error(Discourse::InvalidParameters)
      end

      it "fails when post_revision record is not found" do
        put :revert, params: {
          post_id: post.id, revision: post_revision.number + 1
        }, format: :json
        expect(response).to_not be_success
      end

      it "fails when post record is not found" do
        put :revert, params: {
          post_id: post.id + 1, revision: post_revision.number
        }, format: :json
        expect(response).to_not be_success
      end

      it "fails when revision is blank" do
        put :revert, params: {
          post_id: post.id, revision: blank_post_revision.number
        }, format: :json

        expect(response.status).to eq(422)
        expect(JSON.parse(response.body)['errors']).to include(I18n.t('revert_version_same'))
      end

      it "fails when revised version is same as current version" do
        put :revert, params: {
          post_id: post.id, revision: same_post_revision.number
        }, format: :json

        expect(response.status).to eq(422)
        expect(JSON.parse(response.body)['errors']).to include(I18n.t('revert_version_same'))
      end

      it "works!" do
        put :revert, params: revert_params, format: :json
        expect(response).to be_success
      end

      it "supports reverting posts in deleted topics" do
        first_post = post.topic.ordered_posts.first
        PostDestroyer.new(moderator, first_post).destroy

        put :revert, params: revert_params, format: :json
        expect(response).to be_success
      end
    end
  end

  describe 'expandable embedded posts' do
    let(:post) { Fabricate(:post) }

    it "raises an error when you can't see the post" do
      Guardian.any_instance.expects(:can_see?).with(post).returns(false)
      get :expand_embed, params: { id: post.id }, format: :json
      expect(response).not_to be_success
    end

    it "retrieves the body when you can see the post" do
      Guardian.any_instance.expects(:can_see?).with(post).returns(true)
      TopicEmbed.expects(:expanded_for).with(post).returns("full content")
      get :expand_embed, params: { id: post.id }, format: :json
      expect(response).to be_success
      expect(::JSON.parse(response.body)['cooked']).to eq("full content")
    end
  end

  describe "flagged posts" do

    include_examples "action requires login", :get, :flagged_posts, username: "system"

    describe "when logged in" do
      before { log_in }

      it "raises an error if the user doesn't have permission to see the flagged posts" do
        Guardian.any_instance.expects(:can_see_flagged_posts?).returns(false)
        get :flagged_posts, params: { username: "system" }, format: :json
        expect(response).to be_forbidden
      end

      it "can see the flagged posts when authorized" do
        Guardian.any_instance.expects(:can_see_flagged_posts?).returns(true)
        get :flagged_posts, params: { username: "system" }, format: :json
        expect(response).to be_success
      end

      it "only shows agreed and deferred flags" do
        user = Fabricate(:user)
        post_agreed = create_post(user: user)
        post_deferred = create_post(user: user)
        post_disagreed = create_post(user: user)

        moderator = Fabricate(:moderator)
        PostAction.act(moderator, post_agreed, PostActionType.types[:spam])
        PostAction.act(moderator, post_deferred, PostActionType.types[:off_topic])
        PostAction.act(moderator, post_disagreed, PostActionType.types[:inappropriate])

        admin = Fabricate(:admin)
        PostAction.agree_flags!(post_agreed, admin)
        PostAction.defer_flags!(post_deferred, admin)
        PostAction.clear_flags!(post_disagreed, admin)

        Guardian.any_instance.expects(:can_see_flagged_posts?).returns(true)
        get :flagged_posts, params: { username: user.username }, format: :json
        expect(response).to be_success

        expect(JSON.parse(response.body).length).to eq(2)
      end

    end

  end

  describe "deleted posts" do

    include_examples "action requires login", :get, :deleted_posts, username: "system"

    describe "when logged in" do
      before { log_in }

      it "raises an error if the user doesn't have permission to see the deleted posts" do
        Guardian.any_instance.expects(:can_see_deleted_posts?).returns(false)
        get :deleted_posts, params: { username: "system" }, format: :json
        expect(response).to be_forbidden
      end

      it "can see the deleted posts when authorized" do
        Guardian.any_instance.expects(:can_see_deleted_posts?).returns(true)
        get :deleted_posts, params: { username: "system" }, format: :json
        expect(response).to be_success
      end

      it "doesn't return secured categories for moderators if they don't have access" do
        user = Fabricate(:user)
        admin = Fabricate(:admin)
        Fabricate(:moderator)

        group = Fabricate(:group)
        group.add_owner(user)

        secured_category = Fabricate(:private_category, group: group)
        secured_post = create_post(user: user, category: secured_category)
        PostDestroyer.new(admin, secured_post).destroy

        log_in(:moderator)
        get :deleted_posts, params: { username: user.username }, format: :json
        expect(response).to be_success

        data = JSON.parse(response.body)
        expect(data.length).to eq(0)
      end

      it "doesn't return PMs for moderators" do
        user = Fabricate(:user)
        admin = Fabricate(:admin)
        Fabricate(:moderator)

        pm_post = create_post(user: user, archetype: 'private_message', target_usernames: [admin.username])
        PostDestroyer.new(admin, pm_post).destroy

        log_in(:moderator)
        get :deleted_posts, params: { username: user.username }, format: :json
        expect(response).to be_success

        data = JSON.parse(response.body)
        expect(data.length).to eq(0)
      end

      it "only shows posts deleted by other users" do
        user = Fabricate(:user)
        admin = Fabricate(:admin)

        create_post(user: user)
        post_deleted_by_user = create_post(user: user)
        post_deleted_by_admin = create_post(user: user)

        PostDestroyer.new(user, post_deleted_by_user).destroy
        PostDestroyer.new(admin, post_deleted_by_admin).destroy

        Guardian.any_instance.expects(:can_see_deleted_posts?).returns(true)
        get :deleted_posts, params: { username: user.username }, format: :json
        expect(response).to be_success

        data = JSON.parse(response.body)
        expect(data.length).to eq(1)
        expect(data[0]["id"]).to eq(post_deleted_by_admin.id)
        expect(data[0]["deleted_by"]["id"]).to eq(admin.id)
      end

    end

  end

  describe "view raw" do
    describe "by ID" do
      it "can be viewed by anonymous" do
        post = Fabricate(:post, raw: "123456789")
        get :markdown_id, params: { id: post.id }, format: :json
        expect(response).to be_success
        expect(response.body).to eq("123456789")
      end
    end

    describe "by post number" do
      it "can be viewed by anonymous" do
        topic = Fabricate(:topic)
        post = Fabricate(:post, topic: topic, post_number: 1, raw: "123456789")
        post.save
        get :markdown_num, params: { topic_id: topic.id, post_number: 1 }, format: :json
        expect(response).to be_success
        expect(response.body).to eq("123456789")
      end
    end
  end

  describe "short link" do
    let(:topic) { Fabricate(:topic) }
    let(:post) { Fabricate(:post, topic: topic) }

    it "redirects to the topic" do
      get :short_link, params: { post_id: post.id }, format: :json
      expect(response).to be_redirect
    end

    it "returns a 403 when access is denied" do
      Guardian.any_instance.stubs(:can_see?).returns(false)
      get :short_link, params: { post_id: post.id }, format: :json
      expect(response).to be_forbidden
    end
  end
end
