require 'spec_helper'

shared_examples 'finding and showing post' do
  let(:user) { log_in }
  let(:post) { Fabricate(:post, user: user) }

  it 'ensures the user can see the post' do
    Guardian.any_instance.expects(:can_see?).with(post).returns(false)
    xhr :get, action, params
    expect(response).to be_forbidden
  end

  it 'succeeds' do
    xhr :get, action, params
    expect(response).to be_success
  end

  context "deleted post" do
    before do
      post.trash!(user)
    end

    it "can't find deleted posts as an anonymous user" do
      xhr :get, action, params
      expect(response.status).to eq(404)
    end

    it "can't find deleted posts as a regular user" do
      log_in(:user)
      xhr :get, action, params
      expect(response.status).to eq(404)
    end

    it "can find posts as a moderator" do
      log_in(:moderator)
      xhr :get, action, params
      expect(response).to be_success
    end

    it "can find posts as a admin" do
      log_in(:admin)
      xhr :get, action, params
      expect(response).to be_success
    end
  end
end

shared_examples 'action requires login' do |method, action, params|
  it 'raises an exception when not logged in' do
    expect { xhr method, action, params }.to raise_error(Discourse::NotLoggedIn)
  end
end

describe PostsController do

  describe 'cooked' do
    before do
      post = Post.new(cooked: 'wat')
      PostsController.any_instance.expects(:find_post_from_params).returns(post)
    end

    it 'returns the cooked conent' do
      xhr :get, :cooked, id: 1234
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
      let(:post) { Fabricate(:post, user: user, raw_email: 'email_content') }

      it "raises an error if the user doesn't have permission to view raw email" do
        Guardian.any_instance.expects(:can_view_raw_email?).returns(false)

        xhr :get, :raw_email, id: post.id

        expect(response).to be_forbidden
      end

      it "can view raw email" do
        Guardian.any_instance.expects(:can_view_raw_email?).returns(true)

        xhr :get, :raw_email, id: post.id

        expect(response).to be_success
        json = ::JSON.parse(response.body)
        expect(json['raw_email']).to eq('email_content')
      end

    end

  end

  describe 'show' do
    include_examples 'finding and showing post' do
      let(:action) { :show }
      let(:params) { {id: post.id} }
    end

    it 'gets all the expected fields' do
      # non fabricated test
      new_post = create_post
      xhr :get, :show, {id: new_post.id}
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
      let(:params) { {topic_id: post.topic_id, post_number: post.post_number} }
    end
  end

  describe 'reply_history' do
    include_examples 'finding and showing post' do
      let(:action) { :reply_history }
      let(:params) { {id: post.id} }
    end

    it 'asks post for reply history' do
      Post.any_instance.expects(:reply_history)
      xhr :get, :reply_history, id: post.id
    end
  end

  describe 'replies' do
    include_examples 'finding and showing post' do
      let(:action) { :replies }
      let(:params) { {post_id: post.id} }
    end

    it 'asks post for replies' do
      p1 = Fabricate(:post)
      xhr :get, :replies, post_id: p1.id
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

        xhr :delete, :destroy, id: post.id

        expect(response.status).to eq(422)
        expect(JSON.parse(response.body)['errors']).to include(I18n.t('too_late_to_edit'))
      end

      it "raises an error when the user doesn't have permission to see the post" do
        Guardian.any_instance.expects(:can_delete?).with(post).returns(false)
        xhr :delete, :destroy, id: post.id
        expect(response).to be_forbidden
      end

      it "uses a PostDestroyer" do
        destroyer = mock
        PostDestroyer.expects(:new).returns(destroyer)
        destroyer.expects(:destroy)
        xhr :delete, :destroy, id: post.id
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
        xhr :put, :recover, post_id: post.id
        expect(response).to be_forbidden
      end

      it "recovers a post correctly" do
        topic_id = create_post.topic_id
        post = create_post(topic_id: topic_id)

        PostDestroyer.new(user, post).destroy
        xhr :put, :recover, post_id: post.id
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
        expect { xhr :delete, :destroy_many }.to raise_error(ActionController::ParameterMissing)
      end

      it "raises invalid parameters with missing ids" do
        expect { xhr :delete, :destroy_many, post_ids: [12345] }.to raise_error(Discourse::InvalidParameters)
      end

      it "raises an error when the user doesn't have permission to delete the posts" do
        Guardian.any_instance.expects(:can_delete?).with(instance_of(Post)).returns(false)
        xhr :delete, :destroy_many, post_ids: [post1.id, post2.id]
        expect(response).to be_forbidden
      end

      it "deletes the post" do
        PostDestroyer.any_instance.expects(:destroy).twice
        xhr :delete, :destroy_many, post_ids: [post1.id, post2.id]
      end

      it "updates the highest read data for the forum" do
        Topic.expects(:reset_highest).twice
        xhr :delete, :destroy_many, post_ids: [post1.id, post2.id]
      end

      describe "can delete replies" do

        before do
          PostReply.create(post_id: post1.id, reply_id: post2.id)
        end

        it "deletes the post and the reply to it" do
          PostDestroyer.any_instance.expects(:destroy).twice
          xhr :delete, :destroy_many, post_ids: [post1.id], reply_post_ids: [post1.id]
        end

      end

    end

  end

  describe 'edit a post' do

    include_examples 'action requires login', :put, :update, id: 2

    describe 'when logged in' do

      let(:post) { Fabricate(:post, user: log_in) }
      let(:update_params) do
        {
          id: post.id,
          post: { raw: 'edited body', edit_reason: 'typo' },
          image_sizes: { 'http://image.com/image.jpg' => {'width' => 123, 'height' => 456} },
        }
      end

      it 'does not allow to update when edit time limit expired' do
        Guardian.any_instance.stubs(:can_edit?).with(post).returns(false)
        Post.any_instance.stubs(:edit_time_limit_expired?).returns(true)

        xhr :put, :update, update_params

        expect(response.status).to eq(422)
        expect(JSON.parse(response.body)['errors']).to include(I18n.t('too_late_to_edit'))
      end

      it 'passes the image sizes through' do
        Post.any_instance.expects(:image_sizes=)
        xhr :put, :update, update_params
      end

      it 'passes the edit reason through' do
        Post.any_instance.expects(:edit_reason=)
        xhr :put, :update, update_params
      end

      it "raises an error when the post parameter is missing" do
        update_params.delete(:post)
        expect {
          xhr :put, :update, update_params
        }.to raise_error(ActionController::ParameterMissing)
      end

      it "raises an error when the user doesn't have permission to see the post" do
        Guardian.any_instance.expects(:can_edit?).with(post).at_least_once.returns(false)
        xhr :put, :update, update_params
        expect(response).to be_forbidden
      end

      it "calls revise with valid parameters" do
        PostRevisor.any_instance.expects(:revise!).with(post.user, { raw: 'edited body' , edit_reason: 'typo' }, anything)
        xhr :put, :update, update_params
      end

      it "extracts links from the new body" do
        TopicLink.expects(:extract_from).with(post)
        xhr :put, :update, update_params
      end

    end

  end

  describe 'bookmark a post' do

    include_examples 'action requires login', :put, :bookmark, post_id: 2

    describe 'when logged in' do

      let(:post) { Fabricate(:post, user: log_in) }

      it "raises an error if the user doesn't have permission to see the post" do
        Guardian.any_instance.expects(:can_see?).with(post).returns(false).once

        xhr :put, :bookmark, post_id: post.id, bookmarked: 'true'
        expect(response).to be_forbidden
      end

      it 'creates a bookmark' do
        PostAction.expects(:act).with(post.user, post, PostActionType.types[:bookmark])
        xhr :put, :bookmark, post_id: post.id, bookmarked: 'true'
      end

      it 'removes a bookmark' do
        PostAction.expects(:remove_act).with(post.user, post, PostActionType.types[:bookmark])
        xhr :put, :bookmark, post_id: post.id
      end

    end

  end

  describe "wiki" do

    include_examples "action requires login", :put, :wiki, post_id: 2

    describe "when logged in" do
      let(:user) {log_in}
      let(:post) {Fabricate(:post, user: user)}

      it "raises an error if the user doesn't have permission to wiki the post" do
        Guardian.any_instance.expects(:can_wiki?).returns(false)

        xhr :put, :wiki, post_id: post.id, wiki: 'true'

        expect(response).to be_forbidden
      end

      it "can wiki a post" do
        Guardian.any_instance.expects(:can_wiki?).returns(true)

        xhr :put, :wiki, post_id: post.id, wiki: 'true'

        post.reload
        expect(post.wiki).to eq(true)
      end

      it "can unwiki a post" do
        wikied_post = Fabricate(:post, user: user, wiki: true)
        Guardian.any_instance.expects(:can_wiki?).returns(true)

        xhr :put, :wiki, post_id: wikied_post.id, wiki: 'false'

        wikied_post.reload
        expect(wikied_post.wiki).to eq(false)
      end

    end

  end

  describe "post_type" do

    include_examples "action requires login", :put, :post_type, post_id: 2

    describe "when logged in" do
      let(:user) {log_in}
      let(:post) {Fabricate(:post, user: user)}

      it "raises an error if the user doesn't have permission to change the post type" do
        Guardian.any_instance.expects(:can_change_post_type?).returns(false)

        xhr :put, :post_type, post_id: post.id, post_type: 2

        expect(response).to be_forbidden
      end

      it "can change the post type" do
        Guardian.any_instance.expects(:can_change_post_type?).returns(true)

        xhr :put, :post_type, post_id: post.id, post_type: 2

        post.reload
        expect(post.post_type).to eq(2)
      end

    end

  end

  describe "rebake" do

    include_examples "action requires login", :put, :rebake, post_id: 2

    describe "when logged in" do
      let(:user) {log_in}
      let(:post) {Fabricate(:post, user: user)}

      it "raises an error if the user doesn't have permission to rebake the post" do
        Guardian.any_instance.expects(:can_rebake?).returns(false)

        xhr :put, :rebake, post_id: post.id

        expect(response).to be_forbidden
      end

      it "can rebake the post" do
        Guardian.any_instance.expects(:can_rebake?).returns(true)

        xhr :put, :rebake, post_id: post.id

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

        xhr :post, :create, {api_username: user.username, api_key: master_key, raw: raw, title: title, wpid: 1}
        expect(response).to be_success
        original = response.body

        xhr :post, :create, {api_username: user.username_lower, api_key: master_key, raw: raw, title: title, wpid: 2}
        expect(response).to be_success

        expect(response.body).to eq(original)
      end
    end

    describe 'when logged in' do

      let!(:user) { log_in }
      let(:moderator) { log_in(:moderator) }
      let(:new_post) { Fabricate.build(:post, user: user) }

      it "raises an exception without a raw parameter" do
	      expect { xhr :post, :create }.to raise_error(ActionController::ParameterMissing)
      end

      it 'queues the post if min_first_post_typing_time is not met' do

        SiteSetting.min_first_post_typing_time = 3000
        # our logged on user here is tl1
        SiteSetting.auto_block_fast_typers_max_trust_level = 1

        xhr :post, :create, {raw: 'this is the test content', title: 'this is the test title for the topic'}

        expect(response).to be_success
        parsed = ::JSON.parse(response.body)

        expect(parsed["action"]).to eq("enqueued")

        user.reload
        expect(user.blocked).to eq(true)

        qp = QueuedPost.first

        mod = Fabricate(:moderator)
        qp.approve!(mod)

        user.reload
        expect(user.blocked).to eq(false)

      end

      it 'blocks correctly based on auto_block_first_post_regex' do
        SiteSetting.auto_block_first_post_regex = "I love candy|i eat s[1-5]"

        xhr :post, :create, {raw: 'this is the test content', title: 'when I eat s3 sometimes when not looking'}

        expect(response).to be_success
        parsed = ::JSON.parse(response.body)

        expect(parsed["action"]).to eq("enqueued")

        user.reload
        expect(user.blocked).to eq(true)
      end

      it 'creates the post' do
        xhr :post, :create, {raw: 'this is the test content', title: 'this is the test title for the topic'}

        expect(response).to be_success
        parsed = ::JSON.parse(response.body)

        # Deprecated structure
        expect(parsed['post']).to be_blank
        expect(parsed['cooked']).to be_present
      end

      it "returns the nested post with a param" do
        xhr :post, :create, {raw: 'this is the test content',
                             title: 'this is the test title for the topic',
                             nested_post: true}

        expect(response).to be_success
        parsed = ::JSON.parse(response.body)
        expect(parsed['post']).to be_present
        expect(parsed['post']['cooked']).to be_present
      end

      it 'protects against dupes' do
        raw = "this is a test post 123 #{SecureRandom.hash}"
        title = "this is a title #{SecureRandom.hash}"

        xhr :post, :create, {raw: raw, title: title, wpid: 1}
        expect(response).to be_success

        xhr :post, :create, {raw: raw, title: title, wpid: 2}
        expect(response).not_to be_success
      end

      context "errors" do

        let(:post_with_errors) { Fabricate.build(:post, user: user)}

        before do
          post_with_errors.errors.add(:base, I18n.t(:spamming_host))
          PostCreator.any_instance.stubs(:errors).returns(post_with_errors.errors)
          PostCreator.any_instance.expects(:create).returns(post_with_errors)
        end

        it "does not succeed" do
          xhr :post, :create, {raw: 'test'}
          User.any_instance.expects(:flag_linked_posts_as_spam).never
          expect(response).not_to be_success
        end

        it "it triggers flag_linked_posts_as_spam when the post creator returns spam" do
          PostCreator.any_instance.expects(:spam?).returns(true)
          User.any_instance.expects(:flag_linked_posts_as_spam)
          xhr :post, :create, {raw: 'test'}
        end

      end


      context "parameters" do

        before do
          # Just for performance, no reason to actually perform for these
          # tests.
          NewPostManager.stubs(:perform).returns(NewPostResult)
        end

        it "passes raw through" do
          xhr :post, :create, {raw: 'hello'}
          expect(assigns(:manager_params)['raw']).to eq('hello')
        end

        it "passes title through" do
          xhr :post, :create, {raw: 'hello', title: 'new topic title'}
          expect(assigns(:manager_params)['title']).to eq('new topic title')
        end

        it "passes topic_id through" do
          xhr :post, :create, {raw: 'hello', topic_id: 1234}
          expect(assigns(:manager_params)['topic_id']).to eq('1234')
        end

        it "passes archetype through" do
          xhr :post, :create, {raw: 'hello', archetype: 'private_message'}
          expect(assigns(:manager_params)['archetype']).to eq('private_message')
        end

        it "passes category through" do
          xhr :post, :create, {raw: 'hello', category: 'cool'}
          expect(assigns(:manager_params)['category']).to eq('cool')
        end

        it "passes target_usernames through" do
          xhr :post, :create, {raw: 'hello', target_usernames: 'evil,trout'}
          expect(assigns(:manager_params)['target_usernames']).to eq('evil,trout')
        end

        it "passes reply_to_post_number through" do
          xhr :post, :create, {raw: 'hello', reply_to_post_number: 6789, topic_id: 1234}
          expect(assigns(:manager_params)['reply_to_post_number']).to eq('6789')
        end

        it "passes image_sizes through" do
          xhr :post, :create, {raw: 'hello', image_sizes: {width: '100', height: '200'}}
          expect(assigns(:manager_params)['image_sizes']['width']).to eq('100')
          expect(assigns(:manager_params)['image_sizes']['height']).to eq('200')
        end

        it "passes meta_data through" do
          xhr :post, :create, {raw: 'hello', meta_data: {xyz: 'abc'}}
          expect(assigns(:manager_params)['meta_data']['xyz']).to eq('abc')
        end

        context "is_warning" do
          it "doesn't pass `is_warning` through if you're not staff" do
            xhr :post, :create, {raw: 'hello', archetype: 'private_message', is_warning: 'true'}
            expect(assigns(:manager_params)['is_warning']).to eq(false)
          end

          it "passes `is_warning` through if you're staff" do
            log_in(:moderator)
            xhr :post, :create, {raw: 'hello', archetype: 'private_message', is_warning: 'true'}
            expect(assigns(:manager_params)['is_warning']).to eq(true)
          end

          it "passes `is_warning` as false through if you're staff" do
            xhr :post, :create, {raw: 'hello', archetype: 'private_message', is_warning: 'false'}
            expect(assigns(:manager_params)['is_warning']).to eq(false)
          end

        end

      end

    end
  end

  describe "revisions" do

    let(:post) { Fabricate(:post, version: 2) }
    let(:post_revision) { Fabricate(:post_revision, post: post) }

    it "throws an exception when revision is < 2" do
      expect {
        xhr :get, :revisions, post_id: post_revision.post_id, revision: 1
      }.to raise_error(Discourse::InvalidParameters)
    end

    context "when edit history is not visible to the public" do

      before { SiteSetting.stubs(:edit_history_visible_to_public).returns(false) }

      it "ensures anonymous cannot see the revisions" do
        xhr :get, :revisions, post_id: post_revision.post_id, revision: post_revision.number
        expect(response).to be_forbidden
      end

      it "ensures regular user cannot see the revisions" do
        log_in(:user)
        xhr :get, :revisions, post_id: post_revision.post_id, revision: post_revision.number
        expect(response).to be_forbidden
      end

      it "ensures staff can see the revisions" do
        log_in(:admin)
        xhr :get, :revisions, post_id: post_revision.post_id, revision: post_revision.number
        expect(response).to be_success
      end

      it "ensures poster can see the revisions" do
        user = log_in(:active_user)
        post = Fabricate(:post, user: user, version: 3)
        pr = Fabricate(:post_revision, user: user, post: post)
        xhr :get, :revisions, post_id: pr.post_id, revision: pr.number
        expect(response).to be_success
      end

      it "ensures trust level 4 can see the revisions" do
        log_in(:trust_level_4)
        xhr :get, :revisions, post_id: post_revision.post_id, revision: post_revision.number
        expect(response).to be_success
      end

    end

    context "when edit history is visible to everyone" do

      before { SiteSetting.stubs(:edit_history_visible_to_public).returns(true) }

      it "ensures anyone can see the revisions" do
        xhr :get, :revisions, post_id: post_revision.post_id, revision: post_revision.number
        expect(response).to be_success
      end

    end

    context "deleted post" do
      let(:admin) { log_in(:admin) }
      let(:deleted_post) { Fabricate(:post, user: admin, version: 3) }
      let(:deleted_post_revision) { Fabricate(:post_revision, user: admin, post: deleted_post) }

      before { deleted_post.trash!(admin) }

      it "also work on deleted post" do
        xhr :get, :revisions, post_id: deleted_post_revision.post_id, revision: deleted_post_revision.number
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
        xhr :get, :revisions, post_id: post_revision.post_id, revision: post_revision.number
        expect(response).to be_success
      end
    end

  end

  describe 'expandable embedded posts' do
    let(:post) { Fabricate(:post) }

    it "raises an error when you can't see the post" do
      Guardian.any_instance.expects(:can_see?).with(post).returns(false)
      xhr :get, :expand_embed, id: post.id
      expect(response).not_to be_success
    end

    it "retrieves the body when you can see the post" do
      Guardian.any_instance.expects(:can_see?).with(post).returns(true)
      TopicEmbed.expects(:expanded_for).with(post).returns("full content")
      xhr :get, :expand_embed, id: post.id
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
        xhr :get, :flagged_posts, username: "system"
        expect(response).to be_forbidden
      end

      it "can see the flagged posts when authorized" do
        Guardian.any_instance.expects(:can_see_flagged_posts?).returns(true)
        xhr :get, :flagged_posts, username: "system"
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
        xhr :get, :flagged_posts, username: user.username
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
        xhr :get, :deleted_posts, username: "system"
        expect(response).to be_forbidden
      end

      it "can see the deleted posts when authorized" do
        Guardian.any_instance.expects(:can_see_deleted_posts?).returns(true)
        xhr :get, :deleted_posts, username: "system"
        expect(response).to be_success
      end

      it "doesn't return secured categories for moderators if they don't have access" do
        user = Fabricate(:user)
        admin = Fabricate(:admin)
        Fabricate(:moderator)

        group = Fabricate(:group)
        group.add(user)
        group.appoint_manager(user)

        secured_category = Fabricate(:private_category, group: group)
        secured_post = create_post(user: user, category: secured_category)
        PostDestroyer.new(admin, secured_post).destroy

        log_in(:moderator)
        xhr :get, :deleted_posts, username: user.username
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
        xhr :get, :deleted_posts, username: user.username
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
        xhr :get, :deleted_posts, username: user.username
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
        xhr :get, :markdown_id, id: post.id
        expect(response).to be_success
        expect(response.body).to eq("123456789")
      end
    end

    describe "by post number" do
      it "can be viewed by anonymous" do
        topic = Fabricate(:topic)
        post = Fabricate(:post, topic: topic, post_number: 1, raw: "123456789")
        post.save
        xhr :get, :markdown_num, topic_id: topic.id, post_number: 1
        expect(response).to be_success
        expect(response.body).to eq("123456789")
      end
    end
  end

  describe "short link" do
    let(:topic) { Fabricate(:topic) }
    let(:post) { Fabricate(:post, topic: topic) }

    it "redirects to the topic" do
      xhr :get, :short_link, post_id: post.id
      expect(response).to be_redirect
    end

    it "returns a 403 when access is denied" do
      Guardian.any_instance.stubs(:can_see?).returns(false)
      xhr :get, :short_link, post_id: post.id
      expect(response).to be_forbidden
    end
  end
end
