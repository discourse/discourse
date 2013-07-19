require 'spec_helper'

describe PostGuardian do
  let(:user) { build(:user) }
  let(:moderator) { build(:moderator) }
  let(:admin) { build(:admin) }
  let(:coding_horror) { build(:coding_horror) }
  let(:another_admin) { build(:admin) }

  let(:topic) { build(:topic, user: user) }
  let(:post) { build(:post, topic: topic, user: topic.user) }

  describe "can_clear_flags?" do
    it "returns false when the user is nil" do
      Guardian.new(nil).can_clear_flags?(post).should be_false
    end

    it "returns false when the post is nil" do
      Guardian.new(moderator).can_clear_flags?(nil).should be_false
    end

    it "returns false when the user is not a moderator" do
      Guardian.new(user).can_clear_flags?(post).should be_false
    end

    it "returns true when the user is a moderator" do
      Guardian.new(moderator).can_clear_flags?(post).should be_true
    end
  end

  describe 'can_see_post_actors?' do
    let(:topic) { Fabricate(:topic, user: coding_horror)}

    it 'displays visibility correctly' do
      guardian = Guardian.new(user)
      guardian.can_see_post_actors?(nil, PostActionType.types[:like]).should be_false
      guardian.can_see_post_actors?(topic, PostActionType.types[:like]).should be_true
      guardian.can_see_post_actors?(topic, PostActionType.types[:bookmark]).should be_false
      guardian.can_see_post_actors?(topic, PostActionType.types[:off_topic]).should be_false
      guardian.can_see_post_actors?(topic, PostActionType.types[:spam]).should be_false
      guardian.can_see_post_actors?(topic, PostActionType.types[:vote]).should be_true
    end

    it 'returns false for private votes' do
      topic.expects(:has_meta_data_boolean?).with(:private_poll).returns(true)
      Guardian.new(user).can_see_post_actors?(topic, PostActionType.types[:vote]).should be_false
    end
  end

  describe 'can_invite_to?' do
    let(:topic) { Fabricate(:topic) }
    let(:user) { topic.user }

    it 'handles invitation correctly' do
      Guardian.new(nil).can_invite_to?(topic).should be_false
      Guardian.new(moderator).can_invite_to?(nil).should be_false
      Guardian.new(moderator).can_invite_to?(topic).should be_true
      Guardian.new(user).can_invite_to?(topic).should be_false
    end

    it 'returns true when the site requires approving users and is mod' do
      SiteSetting.expects(:must_approve_users?).returns(true)
      Guardian.new(moderator).can_invite_to?(topic).should be_true
    end

    it 'returns true when the site requires approving users and is regular' do
      SiteSetting.expects(:must_approve_users?).returns(true)
      Guardian.new(coding_horror).can_invite_to?(topic).should be_false
    end
  end

  describe 'post_can_act?' do
    it "isn't allowed on nil" do
      Guardian.new(user).post_can_act?(nil, nil).should be_false
    end

    describe 'a Post' do
      let (:guardian) { Guardian.new(user) }

      it "isn't allowed when not logged in" do
        Guardian.new(nil).post_can_act?(post,:vote).should be_false
      end

      it "is allowed as a regular user" do
        guardian.post_can_act?(post,:vote).should be_true
      end

      it "doesn't allow voting if the user has an action from voting already" do
        guardian.post_can_act?(post,:vote,taken_actions: {PostActionType.types[:vote] => 1}).should be_false
      end

      it "allows voting if the user has performed a different action" do
        guardian.post_can_act?(post,:vote,taken_actions: {PostActionType.types[:like] => 1}).should be_true
      end

      it "isn't allowed on archived topics" do
        topic.archived = true
        Guardian.new(user).post_can_act?(post,:like).should be_false
      end

      describe 'multiple voting' do
        it "isn't allowed if the user voted and the topic doesn't allow multiple votes" do
          Topic.any_instance.expects(:has_meta_data_boolean?).with(:single_vote).returns(true)
          Guardian.new(user).can_vote?(post, voted_in_topic: true).should be_false
        end

        it "is allowed if the user voted and the topic doesn't allow multiple votes" do
          Guardian.new(user).can_vote?(post, voted_in_topic: false).should be_true
        end
      end
    end
  end

  describe 'post_can_act?' do
    let(:post) { build(:post) }

    it "returns false when the user is nil" do
      Guardian.new(nil).post_can_act?(post, :like).should be_false
    end

    it "returns false when the post is nil" do
      Guardian.new(user).post_can_act?(nil, :like).should be_false
    end

    it "returns false when the topic is archived" do
      post.topic.archived = true
      Guardian.new(user).post_can_act?(post, :like).should be_false
    end

    it "always allows flagging" do
      post.topic.archived = true
      Guardian.new(user).post_can_act?(post, :spam).should be_true
    end

    it "returns false when liking yourself" do
      Guardian.new(post.user).post_can_act?(post, :like).should be_false
    end

    it "returns false when you've already done it" do
      Guardian.new(user).post_can_act?(post, :like, taken_actions: {PostActionType.types[:like] => 1}).should be_false
    end

    it "returns false when you already flagged a post" do
      Guardian.new(user).post_can_act?(post, :off_topic, taken_actions: {PostActionType.types[:spam] => 1}).should be_false
    end

    describe "trust levels" do
      it "returns true for a new user liking something" do
        user.trust_level = TrustLevel.levels[:new]
        Guardian.new(user).post_can_act?(post, :like).should be_true
      end

      it "returns false for a new user flagging something as spam" do
        user.trust_level = TrustLevel.levels[:new]
        Guardian.new(user).post_can_act?(post, :spam).should be_false
      end

      it "returns false for a new user flagging something as off topic" do
        user.trust_level = TrustLevel.levels[:new]
        Guardian.new(user).post_can_act?(post, :off_topic).should be_false
      end
    end
  end

  describe 'can_delete_post_action?' do
    let(:post_action) do
      user.id = 1
      post.id = 1

      a = PostAction.new(user: user, post: post, post_action_type_id: 1)
      a.created_at = 1.minute.ago
      a
    end

    it 'returns false when not logged in' do
      Guardian.new.can_delete?(post_action).should be_false
    end

    it 'returns false when not the user who created it' do
      Guardian.new(coding_horror).can_delete?(post_action).should be_false
    end

    it "returns false if the window has expired" do
      post_action.created_at = 20.minutes.ago
      SiteSetting.expects(:post_undo_action_window_mins).returns(10)
      Guardian.new(user).can_delete?(post_action).should be_false
    end

    it "returns true if it's yours" do
      Guardian.new(user).can_delete?(post_action).should be_true
    end
  end

  describe 'can_create_post?' do
    it "is false on readonly categories" do
      category = Fabricate(:category)
      topic.category = category
      category.set_permissions(:everyone => :readonly)
      category.save

      Guardian.new(topic.user).can_create?(Post, topic).should be_false
    end

    it "is false when not logged in" do
      Guardian.new.can_create?(Post, topic).should be_false
    end

    it 'is true for a regular user' do
      Guardian.new(topic.user).can_create?(Post, topic).should be_true
    end

    it "is false when you can't see the topic" do
      Guardian.any_instance.expects(:can_see?).with(topic).returns(false)
      Guardian.new(topic.user).can_create?(Post, topic).should be_false
    end

    context 'closed topic' do
      before do
        topic.closed = true
      end

      it "doesn't allow new posts from regular users" do
        Guardian.new(topic.user).can_create?(Post, topic).should be_false
      end

      it 'allows editing of posts' do
        Guardian.new(topic.user).can_edit?(post).should be_true
      end

      it "allows new posts from moderators" do
        Guardian.new(moderator).can_create?(Post, topic).should be_true
      end

      it "allows new posts from admins" do
        Guardian.new(admin).can_create?(Post, topic).should be_true
      end
    end

    context 'archived topic' do
      before do
        topic.archived = true
      end

      context 'regular users' do
        it "doesn't allow new posts from regular users" do
          Guardian.new(coding_horror).can_create?(Post, topic).should be_false
        end

        it 'allows editing of posts' do
          Guardian.new(coding_horror).can_edit?(post).should be_false
        end
      end

      it "allows new posts from moderators" do
        Guardian.new(moderator).can_create?(Post, topic).should be_true
      end

      it "allows new posts from admins" do
        Guardian.new(admin).can_create?(Post, topic).should be_true
      end
    end

    context "trashed topic" do
      before do
        topic.deleted_at = Time.now
      end

      it "doesn't allow new posts from regular users" do
        Guardian.new(coding_horror).can_create?(Post, topic).should be_false
      end

      it "doesn't allow new posts from moderators users" do
        Guardian.new(moderator).can_create?(Post, topic).should be_false
      end

      it "doesn't allow new posts from admins" do
        Guardian.new(admin).can_create?(Post, topic).should be_false
      end
    end
  end
  
  describe 'can_edit_post?' do
    it 'returns false when not logged in' do
      Guardian.new.can_edit?(post).should be_false
    end

    it 'returns true if you want to edit your own post' do
      Guardian.new(post.user).can_edit?(post).should be_true
    end

    it 'returns false if another regular user tries to edit your post' do
      Guardian.new(coding_horror).can_edit?(post).should be_false
    end

    it 'returns true as a moderator' do
      Guardian.new(moderator).can_edit?(post).should be_true
    end

    it 'returns true as an admin' do
      Guardian.new(admin).can_edit?(post).should be_true
    end
  end

  describe 'can_delete_post?' do
    before do
      post.post_number = 2
    end

    it 'returns false when not logged in' do
      Guardian.new.can_delete?(post).should be_false
    end

    it "returns false when trying to delete your own post that has already been deleted" do
      post = Fabricate(:post)
      PostDestroyer.new(user, post).destroy
      post.reload
      Guardian.new(user).can_delete?(post).should be_false
    end

    it 'returns true when trying to delete your own post' do
      Guardian.new(user).can_delete?(post).should be_true
    end

    it "returns false when trying to delete another user's own post" do
      Guardian.new(Fabricate(:user)).can_delete?(post).should be_false
    end

    it "returns false when it's the OP, even as a moderator" do
      post.update_attribute :post_number, 1
      Guardian.new(moderator).can_delete?(post).should be_false
    end

    it 'returns true when a moderator' do
      Guardian.new(moderator).can_delete?(post).should be_true
    end

    it 'returns true when an admin' do
      Guardian.new(admin).can_delete?(post).should be_true
    end
  end

  describe "can_recover_post?" do
    it "returns false for a nil user" do
      Guardian.new(nil).can_recover_post?(post).should be_false
    end

    it "returns false for a nil object" do
      Guardian.new(user).can_recover_post?(nil).should be_false
    end

    it "returns false for a regular user" do
      Guardian.new(user).can_recover_post?(post).should be_false
    end

    it "returns true for a moderator" do
      Guardian.new(moderator).can_recover_post?(post).should be_true
    end
  end

  describe 'can_see_post?' do
    it 'correctly handles post visibility' do
      post = Fabricate(:post)
      topic = post.topic

      Guardian.new(user).can_see?(post).should be_true

      post.trash!(another_admin)
      post.reload
      Guardian.new(user).can_see?(post).should be_false
      Guardian.new(admin).can_see?(post).should be_true

      post.recover!
      post.reload
      topic.trash!(another_admin)
      topic.reload
      Guardian.new(user).can_see?(post).should be_false
      Guardian.new(admin).can_see?(post).should be_true
    end
  end
end
