require 'spec_helper'

describe PostsController do


  describe 'short_link' do
    it 'logs the incoming link once' do
      IncomingLink.expects(:add).once.returns(true)
      p = Fabricate(:post)
      get :short_link, post_id: p.id, user_id: 999
      response.should be_redirect
    end
  end

  describe 'show' do

    let(:post) { Fabricate(:post, user: log_in) }

    it 'ensures the user can see the post' do
      Guardian.any_instance.expects(:can_see?).with(post).returns(false)
      xhr :get, :show, id: post.id
      response.should be_forbidden
    end

    it 'suceeds' do
      xhr :get, :show, id: post.id
      response.should be_success
    end

    context "deleted post" do

      before do
        post.destroy
      end

      it "can't find deleted posts as an anonymous user" do
        xhr :get, :show, id: post.id
        response.should be_forbidden
      end

      it "can't find deleted posts as a regular user" do
        log_in(:user)
        xhr :get, :show, id: post.id
        response.should be_forbidden
      end

      it "can find posts as a moderator" do
        log_in(:moderator)
        xhr :get, :show, id: post.id
        response.should be_success
      end

    end

  end

  describe 'versions' do

    it 'raises an exception when not logged in' do
      lambda { xhr :get, :versions, post_id: 123 }.should raise_error(Discourse::NotLoggedIn)
    end

    describe 'when logged in' do
      let(:post) { Fabricate(:post, user: log_in) }

      it "raises an error if the user doesn't have permission to see the post" do
        Guardian.any_instance.expects(:can_see?).with(post).returns(false)
        xhr :get, :versions, post_id: post.id
        response.should be_forbidden
      end

      it 'renders JSON' do
        xhr :get, :versions, post_id: post.id
        ::JSON.parse(response.body).should be_present
      end

    end

  end

  describe 'delete a post' do
    it 'raises an exception when not logged in' do
      lambda { xhr :delete, :destroy, id: 123 }.should raise_error(Discourse::NotLoggedIn)
    end

    describe 'when logged in' do

      let(:user) { log_in(:moderator) }
      let(:post) { Fabricate(:post, user: user, post_number: 2) }

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
    it 'raises an exception when not logged in' do
      lambda { xhr :put, :recover, post_id: 123 }.should raise_error(Discourse::NotLoggedIn)
    end

    describe 'when logged in' do

      let(:user) { log_in(:moderator) }
      let(:post) { Fabricate(:post, user: user, post_number: 2) }

      it "raises an error when the user doesn't have permission to see the post" do
        Guardian.any_instance.expects(:can_recover_post?).with(post).returns(false)
        xhr :put, :recover, post_id: post.id
        response.should be_forbidden
      end

      it "calls recover" do
        Post.any_instance.expects(:recover)
        xhr :put, :recover, post_id: post.id
      end

    end
  end


  describe 'destroy_many' do
    it 'raises an exception when not logged in' do
      lambda { xhr :delete, :destroy_many, post_ids: [123, 345] }.should raise_error(Discourse::NotLoggedIn)
    end

    describe 'when logged in' do

      let!(:poster) { log_in(:moderator) }
      let!(:post1) { Fabricate(:post, user: poster, post_number: 2) }
      let!(:post2) { Fabricate(:post, topic_id: post1.topic_id, user: poster, post_number: 3) }

      it "raises invalid parameters no post_ids" do
        lambda { xhr :delete, :destroy_many }.should raise_error(Discourse::InvalidParameters)
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
        Post.any_instance.expects(:destroy).twice
        xhr :delete, :destroy_many, post_ids: [post1.id, post2.id]
      end

      it "updates the highest read data for the forum" do
        Topic.expects(:reset_highest)
        xhr :delete, :destroy_many, post_ids: [post1.id, post2.id]
      end

    end

  end


  describe 'edit a post' do

    it 'raises an exception when not logged in' do
      lambda { xhr :put, :update, id: 2 }.should raise_error(Discourse::NotLoggedIn)
    end

    describe 'when logged in' do

      let(:post) { Fabricate(:post, user: log_in) }
      let(:update_params) do
        {id: post.id,
         post: {raw: 'edited body'},
         image_sizes: {'http://image.com/image.jpg' => {'width' => 123, 'height' => 456}}}
      end

      it 'passes the image sizes through' do
        Post.any_instance.expects(:image_sizes=)
        xhr :put, :update, update_params
      end

      it "raises an error when the post parameter is missing" do
        update_params.delete(:post)
        lambda {
          xhr :put, :update, update_params
        }.should raise_error(Discourse::InvalidParameters)
      end

      it "raises an error when the user doesn't have permission to see the post" do
        Guardian.any_instance.expects(:can_edit?).with(post).returns(false)
        xhr :put, :update, update_params
        response.should be_forbidden
      end

      it "calls revise with valid parameters" do
        PostRevisor.any_instance.expects(:revise!).with(post.user, 'edited body')
        xhr :put, :update, update_params
      end

      it "extracts links from the new body" do
        TopicLink.expects(:extract_from).with(post)
        xhr :put, :update, update_params
      end

    end

  end

  describe 'bookmark a post' do

    it 'raises an exception when not logged in' do
      lambda { xhr :put, :bookmark, post_id: 2 }.should raise_error(Discourse::NotLoggedIn)
    end

    describe 'when logged in' do

      let(:post) { Fabricate(:post, user: log_in) }

      it "raises an error if the user doesn't have permission to see the post" do
        Guardian.any_instance.expects(:can_see?).with(post).returns(false)
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

  describe 'creating a post' do

    it 'raises an exception when not logged in' do
      lambda { xhr :post, :create }.should raise_error(Discourse::NotLoggedIn)
    end

    describe 'when logged in' do

      let!(:user) { log_in }
      let(:new_post) { Fabricate.build(:post, user: user) }

      it "raises an exception without a post parameter" do
        lambda { xhr :post, :create }.should raise_error(Discourse::InvalidParameters)
      end

      it 'calls the post creator' do
        PostCreator.any_instance.expects(:create).returns(new_post)
        xhr :post, :create, post: {raw: 'test'}
        response.should be_success
      end

      it 'returns JSON of the post' do
        PostCreator.any_instance.expects(:create).returns(new_post)
        xhr :post, :create, post: {raw: 'test'}
        ::JSON.parse(response.body).should be_present
      end

      context "parameters" do

        let(:post_creator) { mock }

        before do
          post_creator.expects(:create).returns(new_post)
          post_creator.stubs(:errors).returns(nil)
        end

        it "passes raw through" do
          PostCreator.expects(:new).with(user, has_entries(raw: 'hello')).returns(post_creator)
          xhr :post, :create, post: {raw: 'hello'}
        end

        it "passes title through" do
          PostCreator.expects(:new).with(user, has_entries(title: 'new topic title')).returns(post_creator)
          xhr :post, :create, post: {raw: 'hello'}, title: 'new topic title'
        end

        it "passes topic_id through" do
          PostCreator.expects(:new).with(user, has_entries(topic_id: '1234')).returns(post_creator)
          xhr :post, :create, post: {raw: 'hello', topic_id: 1234}
        end

        it "passes archetype through" do
          PostCreator.expects(:new).with(user, has_entries(archetype: 'private_message')).returns(post_creator)
          xhr :post, :create, post: {raw: 'hello'}, archetype: 'private_message'
        end

        it "passes category through" do
          PostCreator.expects(:new).with(user, has_entries(category: 'cool')).returns(post_creator)
          xhr :post, :create, post: {raw: 'hello', category: 'cool'}
        end

        it "passes target_usernames through" do
          PostCreator.expects(:new).with(user, has_entries(target_usernames: 'evil,trout')).returns(post_creator)
          xhr :post, :create, post: {raw: 'hello'}, target_usernames: 'evil,trout'
        end

        it "passes reply_to_post_number through" do
          PostCreator.expects(:new).with(user, has_entries(reply_to_post_number: '6789')).returns(post_creator)
          xhr :post, :create, post: {raw: 'hello', reply_to_post_number: 6789}
        end

        it "passes image_sizes through" do
          PostCreator.expects(:new).with(user, has_entries(image_sizes: 'test')).returns(post_creator)
          xhr :post, :create, post: {raw: 'hello'}, image_sizes: 'test'
        end

        it "passes meta_data through" do
          PostCreator.expects(:new).with(user, has_entries(meta_data: {'xyz' => 'abc'})).returns(post_creator)
          xhr :post, :create, post: {raw: 'hello'}, meta_data: {xyz: 'abc'}
        end

      end

    end
  end

end
