require 'spec_helper'

shared_examples 'finding and showing post' do
  let(:user) { log_in }
  let(:post) { Fabricate(:post, user: user) }

  it 'ensures the user can see the post' do
    Guardian.any_instance.expects(:can_see?).with(post).returns(false)
    xhr :get, action, params
    response.should be_forbidden
  end

  it 'succeeds' do
    xhr :get, action, params
    response.should be_success
  end

  context "deleted post" do
    before do
      post.trash!(user)
    end

    it "can't find deleted posts as an anonymous user" do
      xhr :get, action, params
      response.should be_forbidden
    end

    it "can't find deleted posts as a regular user" do
      log_in(:user)
      xhr :get, action, params
      response.should be_forbidden
    end

    it "can find posts as a moderator" do
      log_in(:moderator)
      xhr :get, action, params
      response.should be_success
    end
  end
end

shared_examples 'action requires login' do |method, action, params|
  it 'raises an exception when not logged in' do
    lambda { xhr method, action, params }.should raise_error(Discourse::NotLoggedIn)
  end
end

describe PostsController do

  describe 'short_link' do
    let(:post) { Fabricate(:post) }

    it 'logs the incoming link once' do
      IncomingLink.expects(:add).once.returns(true)
      get :short_link, post_id: post.id, user_id: 999
      response.should be_redirect
    end
  end

  describe 'cooked' do
    before do
      post = Post.new(cooked: 'wat')
      PostsController.any_instance.expects(:find_post_from_params).returns(post)
    end

    it 'returns the cooked conent' do
      xhr :get, :cooked, id: 1234
      response.should be_success
      json = ::JSON.parse(response.body)
      json.should be_present
      json['cooked'].should == 'wat'
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
      parsed["topic_slug"].should == new_post.topic.slug
      parsed["moderator"].should == false
      parsed["username"].should == new_post.user.username
      parsed["cooked"].should == new_post.cooked
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
      Post.any_instance.expects(:replies)
      xhr :get, :replies, post_id: post.id
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

        response.status.should == 422
        JSON.parse(response.body)['errors'].should include(I18n.t('too_late_to_edit'))
      end

      it "raises an error when the user doesn't have permission to see the post" do
        Guardian.any_instance.expects(:can_delete?).with(post).returns(false)
        xhr :delete, :destroy, id: post.id
        response.should be_forbidden
      end

      it "uses a PostDestroyer" do
        destroyer = mock
        PostDestroyer.expects(:new).with(user, post).returns(destroyer)
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
        response.should be_forbidden
      end

      it "recovers a post correctly" do
        topic_id = create_post.topic_id
        post = create_post(topic_id: topic_id)

        PostDestroyer.new(user, post).destroy
        xhr :put, :recover, post_id: post.id
        post.reload
        post.deleted_at.should == nil
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
        lambda { xhr :delete, :destroy_many }.should raise_error(ActionController::ParameterMissing)
      end

      it "raises invalid parameters with missing ids" do
        lambda { xhr :delete, :destroy_many, post_ids: [12345] }.should raise_error(Discourse::InvalidParameters)
      end

      it "raises an error when the user doesn't have permission to delete the posts" do
        Guardian.any_instance.expects(:can_delete?).with(instance_of(Post)).returns(false)
        xhr :delete, :destroy_many, post_ids: [post1.id, post2.id]
        response.should be_forbidden
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

        response.status.should == 422
        JSON.parse(response.body)['errors'].should include(I18n.t('too_late_to_edit'))
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
        lambda {
          xhr :put, :update, update_params
        }.should raise_error(ActionController::ParameterMissing)
      end

      it "raises an error when the user doesn't have permission to see the post" do
        Guardian.any_instance.expects(:can_edit?).with(post).at_least_once.returns(false)
        xhr :put, :update, update_params
        response.should be_forbidden
      end

      it "calls revise with valid parameters" do
        PostRevisor.any_instance.expects(:revise!).with(post.user, 'edited body', edit_reason: 'typo')
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
        response.should be_forbidden
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

      it "raises an error if the user doesn't have permission to see the post" do
        Guardian.any_instance.expects(:can_wiki?).returns(false)

        xhr :put, :wiki, post_id: post.id, wiki: 'true'

        response.should be_forbidden
      end

      it "can wiki a post" do
        Guardian.any_instance.expects(:can_wiki?).returns(true)

        xhr :put, :wiki, post_id: post.id, wiki: 'true'

        post.reload
        post.wiki.should be_true
      end

      it "can unwiki a post" do
        wikied_post = Fabricate(:post, user: user, wiki: true)
        Guardian.any_instance.expects(:can_wiki?).returns(true)

        xhr :put, :wiki, post_id: wikied_post.id, wiki: 'false'

        wikied_post.reload
        wikied_post.wiki.should be_false
      end

    end

  end

  describe 'creating a post' do

    include_examples 'action requires login', :post, :create

    describe 'when logged in' do

      let!(:user) { log_in }
      let(:new_post) { Fabricate.build(:post, user: user) }

      it "raises an exception without a raw parameter" do
	      lambda { xhr :post, :create }.should raise_error(ActionController::ParameterMissing)
      end

      it 'calls the post creator' do
        PostCreator.any_instance.expects(:create).returns(new_post)
        xhr :post, :create, {raw: 'test'}
        response.should be_success
      end

      it 'returns JSON of the post' do
        PostCreator.any_instance.expects(:create).returns(new_post)
        xhr :post, :create, {raw: 'test'}
        ::JSON.parse(response.body).should be_present
      end

      it 'protects against dupes' do
        # TODO we really should be using a mock redis here
        xhr :post, :create, {raw: 'this is a test post 123', title: 'this is a test title 123', wpid: 1}
        response.should be_success
        original = response.body

        xhr :post, :create, {raw: 'this is a test post 123', title: 'this is a test title 123', wpid: 2}
        response.should be_success

        response.body.should == original
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
          response.should_not be_success
        end

        it "it triggers flag_linked_posts_as_spam when the post creator returns spam" do
          PostCreator.any_instance.expects(:spam?).returns(true)
          User.any_instance.expects(:flag_linked_posts_as_spam)
          xhr :post, :create, {raw: 'test'}
        end

      end


      context "parameters" do

        let(:post_creator) { mock }

        before do
          post_creator.expects(:create).returns(new_post)
          post_creator.stubs(:errors).returns(nil)
        end

        it "passes raw through" do
          PostCreator.expects(:new).with(user, has_entries('raw' => 'hello')).returns(post_creator)
          xhr :post, :create, {raw: 'hello'}
        end

        it "passes title through" do
          PostCreator.expects(:new).with(user, has_entries('title' => 'new topic title')).returns(post_creator)
          xhr :post, :create, {raw: 'hello', title: 'new topic title'}
        end

        it "passes topic_id through" do
          PostCreator.expects(:new).with(user, has_entries('topic_id' => '1234')).returns(post_creator)
          xhr :post, :create, {raw: 'hello', topic_id: 1234}
        end

        it "passes archetype through" do
          PostCreator.expects(:new).with(user, has_entries('archetype' => 'private_message')).returns(post_creator)
          xhr :post, :create, {raw: 'hello', archetype: 'private_message'}
        end

        it "passes category through" do
          PostCreator.expects(:new).with(user, has_entries('category' => 'cool')).returns(post_creator)
          xhr :post, :create, {raw: 'hello', category: 'cool'}
        end

        it "passes target_usernames through" do
          PostCreator.expects(:new).with(user, has_entries('target_usernames' => 'evil,trout')).returns(post_creator)
          xhr :post, :create, {raw: 'hello', target_usernames: 'evil,trout'}
        end

        it "passes reply_to_post_number through" do
          PostCreator.expects(:new).with(user, has_entries('reply_to_post_number' => '6789')).returns(post_creator)
          xhr :post, :create, {raw: 'hello', reply_to_post_number: 6789}
        end

        it "passes image_sizes through" do
          PostCreator.expects(:new).with(user, has_entries('image_sizes' => {'width' => '100', 'height' => '200'})).returns(post_creator)
          xhr :post, :create, {raw: 'hello', image_sizes: {width: '100', height: '200'}}
        end

        it "passes meta_data through" do
          PostCreator.expects(:new).with(user, has_entries('meta_data' => {'xyz' => 'abc'})).returns(post_creator)
          xhr :post, :create, {raw: 'hello', meta_data: {xyz: 'abc'}}
        end

      end

    end
  end

  describe "revisions" do

    let(:post_revision) { Fabricate(:post_revision) }

    it "throws an exception when revision is < 2" do
      expect {
        xhr :get, :revisions, post_id: post_revision.post_id, revision: 1
      }.to raise_error(Discourse::InvalidParameters)
    end

    context "when edit history is not visible to the public" do

      before { SiteSetting.stubs(:edit_history_visible_to_public).returns(false) }

      it "ensures anonymous cannot see the revisions" do
        xhr :get, :revisions, post_id: post_revision.post_id, revision: post_revision.number
        response.should be_forbidden
      end

      it "ensures regular user cannot see the revisions" do
        u = log_in(:user)
        xhr :get, :revisions, post_id: post_revision.post_id, revision: post_revision.number
        response.should be_forbidden
      end

      it "ensures staff can see the revisions" do
        log_in(:admin)
        xhr :get, :revisions, post_id: post_revision.post_id, revision: post_revision.number
        response.should be_success
      end

      it "ensures poster can see the revisions" do
        user = log_in(:active_user)
        post = Fabricate(:post, user: user)
        pr = Fabricate(:post_revision, user: user, post: post)
        xhr :get, :revisions, post_id: pr.post_id, revision: pr.number
        response.should be_success
      end

      it "ensures trust level 4 can see the revisions" do
        log_in(:elder)
        xhr :get, :revisions, post_id: post_revision.post_id, revision: post_revision.number
        response.should be_success
      end

    end

    context "when edit history is visible to everyone" do

      before { SiteSetting.stubs(:edit_history_visible_to_public).returns(true) }

      it "ensures anyone can see the revisions" do
        xhr :get, :revisions, post_id: post_revision.post_id, revision: post_revision.number
        response.should be_success
      end

    end

    context "deleted post" do
      let(:admin) { log_in(:admin) }
      let(:deleted_post) { Fabricate(:post, user: admin) }
      let(:deleted_post_revision) { Fabricate(:post_revision, user: admin, post: deleted_post) }

      before { deleted_post.trash!(admin) }

      it "also work on deleted post" do
        xhr :get, :revisions, post_id: deleted_post_revision.post_id, revision: deleted_post_revision.number
        response.should be_success
      end
    end

    context "deleted topic" do
      let(:admin) { log_in(:admin) }
      let(:deleted_topic) { Fabricate(:topic, user: admin) }
      let(:post) { Fabricate(:post, user: admin, topic: deleted_topic) }
      let(:post_revision) { Fabricate(:post_revision, user: admin, post: post) }

      before { deleted_topic.trash!(admin) }

      it "also work on deleted topic" do
        xhr :get, :revisions, post_id: post_revision.post_id, revision: post_revision.number
        response.should be_success
      end
    end

  end

  describe 'expandable embedded posts' do
    let(:post) { Fabricate(:post) }

    it "raises an error when you can't see the post" do
      Guardian.any_instance.expects(:can_see?).with(post).returns(false)
      xhr :get, :expand_embed, id: post.id
      response.should_not be_success
    end

    it "retrieves the body when you can see the post" do
      Guardian.any_instance.expects(:can_see?).with(post).returns(true)
      TopicEmbed.expects(:expanded_for).with(post).returns("full content")
      xhr :get, :expand_embed, id: post.id
      response.should be_success
      ::JSON.parse(response.body)['cooked'].should == "full content"
    end
  end
end
