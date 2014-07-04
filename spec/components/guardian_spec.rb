require 'spec_helper'
require 'guardian'
require_dependency 'post_destroyer'

describe Guardian do

  let(:user) { build(:user) }
  let(:moderator) { build(:moderator) }
  let(:admin) { build(:admin) }
  let(:leader) { build(:user, trust_level: 3) }
  let(:elder)  { build(:user, trust_level: 4) }
  let(:another_admin) { build(:admin) }
  let(:coding_horror) { build(:coding_horror) }

  let(:topic) { build(:topic, user: user) }
  let(:post) { build(:post, topic: topic, user: topic.user) }

  it 'can be created without a user (not logged in)' do
    lambda { Guardian.new }.should_not raise_error
  end

  it 'can be instantiaed with a user instance' do
    lambda { Guardian.new(user) }.should_not raise_error
  end

  describe 'post_can_act?' do
    let(:post) { build(:post) }
    let(:user) { build(:user) }

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

      it "returns false for a new user flagging with notify_user" do
        user.trust_level = TrustLevel.levels[:new]
        Guardian.new(user).post_can_act?(post, :notify_user).should be_false # because new users can't send private messages
      end
    end
  end


  describe "can_clear_flags" do
    let(:post) { Fabricate(:post) }
    let(:user) { post.user }
    let(:moderator) { Fabricate(:moderator) }

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

  describe 'can_send_private_message' do
    let(:user) { Fabricate(:user) }
    let(:another_user) { Fabricate(:user) }
    let(:suspended_user) { Fabricate(:user, suspended_till: 1.week.from_now, suspended_at: 1.day.ago) }

    it "returns false when the user is nil" do
      Guardian.new(nil).can_send_private_message?(user).should be_false
    end

    it "returns false when the target user is nil" do
      Guardian.new(user).can_send_private_message?(nil).should be_false
    end

    it "returns false when the target is the same as the user" do
      Guardian.new(user).can_send_private_message?(user).should be_false
    end

    it "returns false when you are untrusted" do
      user.trust_level = TrustLevel.levels[:new]
      Guardian.new(user).can_send_private_message?(another_user).should be_false
    end

    it "returns true to another user" do
      Guardian.new(user).can_send_private_message?(another_user).should be_true
    end

    context "enable_private_messages is false" do
      before { SiteSetting.stubs(:enable_private_messages).returns(false) }

      it "returns false if user is not the contact user" do
        Guardian.new(user).can_send_private_message?(another_user).should be_false
      end

      it "returns true for the contact user and system user" do
        SiteSetting.stubs(:site_contact_username).returns(user.username)
        Guardian.new(user).can_send_private_message?(another_user).should be_true
        Guardian.new(Discourse.system_user).can_send_private_message?(another_user).should be_true
      end
    end

    context "target user is suspended" do
      it "returns true for staff" do
        Guardian.new(admin).can_send_private_message?(suspended_user).should be_true
        Guardian.new(moderator).can_send_private_message?(suspended_user).should be_true
      end

      it "returns false for regular users" do
        Guardian.new(user).can_send_private_message?(suspended_user).should be_false
      end
    end
  end

  describe 'can_reply_as_new_topic' do
    let(:user) { Fabricate(:user) }
    let(:topic) { Fabricate(:topic) }

    it "returns false for a non logged in user" do
      Guardian.new(nil).can_reply_as_new_topic?(topic).should be_false
    end

    it "returns false for a nil topic" do
      Guardian.new(user).can_reply_as_new_topic?(nil).should be_false
    end

    it "returns false for an untrusted user" do
      user.trust_level = TrustLevel.levels[:new]
      Guardian.new(user).can_reply_as_new_topic?(topic).should be_false
    end

    it "returns true for a trusted user" do
      Guardian.new(user).can_reply_as_new_topic?(topic).should be_true
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

  describe 'can_impersonate?' do
    it 'allows impersonation correctly' do
      Guardian.new(admin).can_impersonate?(nil).should be_false
      Guardian.new.can_impersonate?(user).should be_false
      Guardian.new(coding_horror).can_impersonate?(user).should be_false
      Guardian.new(admin).can_impersonate?(admin).should be_false
      Guardian.new(admin).can_impersonate?(another_admin).should be_false
      Guardian.new(admin).can_impersonate?(user).should be_true
      Guardian.new(admin).can_impersonate?(moderator).should be_true

      Rails.configuration.stubs(:developer_emails).returns([admin.email])
      Guardian.new(admin).can_impersonate?(another_admin).should be_true
    end
  end

  describe 'can_invite_to_forum?' do
    let(:user) { Fabricate.build(:user) }
    let(:moderator) { Fabricate.build(:moderator) }

    it "doesn't allow anonymous users to invite" do
      Guardian.new.can_invite_to_forum?.should be_false
    end

    it 'returns true when the site requires approving users and is mod' do
      SiteSetting.expects(:must_approve_users?).returns(true)
      Guardian.new(moderator).can_invite_to_forum?.should be_true
    end

    it 'returns false when the site requires approving users and is regular' do
      SiteSetting.expects(:must_approve_users?).returns(true)
      Guardian.new(user).can_invite_to_forum?.should be_false
    end

    it 'returns false when the local logins are disabled' do
      SiteSetting.stubs(:enable_local_logins).returns(false)
      Guardian.new(user).can_invite_to_forum?.should be_false
      Guardian.new(moderator).can_invite_to_forum?.should be_false
    end

  end

  describe 'can_invite_to?' do
    let(:group) { Fabricate(:group) }
    let(:category) { Fabricate(:category, read_restricted: true) }
    let(:topic) { Fabricate(:topic) }
    let(:private_topic) { Fabricate(:topic, category: category) }
    let(:user) { topic.user }
    let(:moderator) { Fabricate(:moderator) }
    let(:admin) { Fabricate(:admin) }

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

    it 'returns false when the site requires approving users and is regular' do
      SiteSetting.expects(:must_approve_users?).returns(true)
      Guardian.new(coding_horror).can_invite_to?(topic).should be_false
    end

    it 'returns false when local logins are disabled' do
      SiteSetting.stubs(:enable_local_logins).returns(false)
      Guardian.new(moderator).can_invite_to?(topic).should be_false
      Guardian.new(user).can_invite_to?(topic).should be_false
    end

    it 'returns false for normal user on private topic' do
      Guardian.new(user).can_invite_to?(private_topic).should be_false
    end

    it 'returns true for admin on private topic' do
      Guardian.new(admin).can_invite_to?(private_topic).should be_true
    end

  end

  describe 'can_see?' do

    it 'returns false with a nil object' do
      Guardian.new.can_see?(nil).should be_false
    end

    describe 'a Group' do
      let(:group) { Group.new }
      let(:invisible_group) { Group.new(visible: false) }

      it "returns true when the group is visible" do
        Guardian.new.can_see?(group).should be_true
      end

      it "returns true when the group is visible but the user is an admin" do
        admin = Fabricate.build(:admin)
        Guardian.new(admin).can_see?(invisible_group).should be_true
      end

      it "returns false when the group is invisible" do
        Guardian.new.can_see?(invisible_group).should be_false
      end
    end

    describe 'a Topic' do
      it 'allows non logged in users to view topics' do
        Guardian.new.can_see?(topic).should be_true
      end

      it 'correctly handles groups' do
        group = Fabricate(:group)
        category = Fabricate(:category, read_restricted: true)
        category.set_permissions(group => :full)
        category.save

        topic = Fabricate(:topic, category: category)

        Guardian.new(user).can_see?(topic).should be_false
        group.add(user)
        group.save

        Guardian.new(user).can_see?(topic).should be_true
      end

      it "restricts private topics" do
        user.save!
        private_topic = Fabricate(:private_message_topic, user: user)
        Guardian.new(private_topic.user).can_see?(private_topic).should be_true
        Guardian.new(build(:user)).can_see?(private_topic).should be_false
        Guardian.new(moderator).can_see?(private_topic).should be_false
        Guardian.new(admin).can_see?(private_topic).should be_true
      end
    end

    describe 'a Post' do
      let(:another_admin) { Fabricate(:admin) }
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

    describe 'a PostRevision' do
      let(:post_revision) { Fabricate(:post_revision) }

      context 'edit_history_visible_to_public is true' do
        before { SiteSetting.stubs(:edit_history_visible_to_public).returns(true) }

        it 'is false for nil' do
          Guardian.new.can_see?(nil).should be_false
        end

        it 'is true if not logged in' do
          Guardian.new.can_see?(post_revision).should == true
        end

        it 'is true when logged in' do
          Guardian.new(Fabricate(:user)).can_see?(post_revision).should == true
        end
      end

      context 'edit_history_visible_to_public is false' do
        before { SiteSetting.stubs(:edit_history_visible_to_public).returns(false) }

        it 'is true for staff' do
          Guardian.new(Fabricate(:admin)).can_see?(post_revision).should == true
          Guardian.new(Fabricate(:moderator)).can_see?(post_revision).should == true
        end

        it 'is true for trust level 4' do
          Guardian.new(Fabricate(:elder)).can_see?(post_revision).should == true
        end

        it 'is false for trust level lower than 4' do
          Guardian.new(Fabricate(:leader)).can_see?(post_revision).should == false
        end
      end
    end
  end

  describe 'can_create?' do

    describe 'a Category' do

      it 'returns false when not logged in' do
        Guardian.new.can_create?(Category).should be_false
      end

      it 'returns false when a regular user' do
        Guardian.new(user).can_create?(Category).should be_false
      end

      it 'returns false when a moderator' do
        Guardian.new(moderator).can_create?(Category).should be_false
      end

      it 'returns true when an admin' do
        Guardian.new(admin).can_create?(Category).should be_true
      end
    end

    describe 'a Topic' do
      it 'should check for full permissions' do
        category = Fabricate(:category)
        category.set_permissions(:everyone => :create_post)
        category.save
        Guardian.new(user).can_create?(Topic,category).should be_false
      end

      it "is true for new users by default" do
        Guardian.new(user).can_create?(Topic,Fabricate(:category)).should be_true
      end

      it "is false if user has not met minimum trust level" do
        SiteSetting.stubs(:min_trust_to_create_topic).returns(1)
        Guardian.new(build(:user, trust_level: 0)).can_create?(Topic,Fabricate(:category)).should be_false
      end

      it "is true if user has met or exceeded the minimum trust level" do
        SiteSetting.stubs(:min_trust_to_create_topic).returns(1)
        Guardian.new(build(:user, trust_level: 1)).can_create?(Topic,Fabricate(:category)).should be_true
        Guardian.new(build(:user, trust_level: 2)).can_create?(Topic,Fabricate(:category)).should be_true
        Guardian.new(build(:admin, trust_level: 0)).can_create?(Topic,Fabricate(:category)).should be_true
        Guardian.new(build(:moderator, trust_level: 0)).can_create?(Topic,Fabricate(:category)).should be_true
      end
    end

    describe 'a Post' do

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

        it "allows new posts from elders" do
          Guardian.new(elder).can_create?(Post, topic).should be_true
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

  end

  describe 'post_can_act?' do

    it "isn't allowed on nil" do
      Guardian.new(user).post_can_act?(nil, nil).should be_false
    end

    describe 'a Post' do

      let (:guardian) do
        Guardian.new(user)
      end


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

  describe "can_recover_topic?" do

    it "returns false for a nil user" do
      Guardian.new(nil).can_recover_topic?(topic).should be_false
    end

    it "returns false for a nil object" do
      Guardian.new(user).can_recover_topic?(nil).should be_false
    end

    it "returns false for a regular user" do
      Guardian.new(user).can_recover_topic?(topic).should be_false
    end

    it "returns true for a moderator" do
      Guardian.new(moderator).can_recover_topic?(topic).should be_true
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

  describe 'can_edit?' do

    it 'returns false with a nil object' do
      Guardian.new(user).can_edit?(nil).should == false
    end

    describe 'a Post' do

      it 'returns false when not logged in' do
        Guardian.new.can_edit?(post).should be_false
      end

      it 'returns false when not logged in also for wiki post' do
        post.wiki = true
        Guardian.new.can_edit?(post).should be_false
      end

      it 'returns true if you want to edit your own post' do
        Guardian.new(post.user).can_edit?(post).should be_true
      end

      it "returns false if the post is hidden due to flagging and it's too soon" do
        post.hidden = true
        post.hidden_at = Time.now
        Guardian.new(post.user).can_edit?(post).should be_false
      end

      it "returns true if the post is hidden due to flagging and it been enough time" do
        post.hidden = true
        post.hidden_at = (SiteSetting.cooldown_minutes_after_hiding_posts + 1).minutes.ago
        Guardian.new(post.user).can_edit?(post).should be_true
      end

      it "returns true if the post is hidden due to flagging and it's got a nil `hidden_at`" do
        post.hidden = true
        post.hidden_at = nil
        Guardian.new(post.user).can_edit?(post).should be_true
      end

      it 'returns false if you are trying to edit a post you soft deleted' do
        post.user_deleted = true
        Guardian.new(post.user).can_edit?(post).should be_false
      end

      it 'returns false if another regular user tries to edit a soft deleted wiki post' do
        post.wiki = true
        post.user_deleted = true
        Guardian.new(coding_horror).can_edit?(post).should be_false
      end

      it 'returns false if you are trying to edit a deleted post' do
        post.deleted_at = 1.day.ago
        Guardian.new(post.user).can_edit?(post).should be_false
      end

      it 'returns false if another regular user tries to edit a deleted wiki post' do
        post.wiki = true
        post.deleted_at = 1.day.ago
        Guardian.new(coding_horror).can_edit?(post).should be_false
      end

      it 'returns false if another regular user tries to edit your post' do
        Guardian.new(coding_horror).can_edit?(post).should be_false
      end

      it 'returns true if another regular user tries to edit wiki post' do
        post.wiki = true
        Guardian.new(coding_horror).can_edit?(post).should be_true
      end

      it 'returns true as a moderator' do
        Guardian.new(moderator).can_edit?(post).should be_true
      end

      it 'returns true as an admin' do
        Guardian.new(admin).can_edit?(post).should be_true
      end

      it 'returns true as a trust level 4 user' do
        Guardian.new(elder).can_edit?(post).should be_true
      end

      context 'post is older than post_edit_time_limit' do
        let(:old_post) { build(:post, topic: topic, user: topic.user, created_at: 6.minutes.ago) }
        before do
          SiteSetting.stubs(:post_edit_time_limit).returns(5)
        end

        it 'returns false to the author of the post' do
          Guardian.new(old_post.user).can_edit?(old_post).should == false
        end

        it 'returns true as a moderator' do
          Guardian.new(moderator).can_edit?(old_post).should eq(true)
        end

        it 'returns true as an admin' do
          Guardian.new(admin).can_edit?(old_post).should eq(true)
        end

        it 'returns false for another regular user trying to edit your post' do
          Guardian.new(coding_horror).can_edit?(old_post).should == false
        end

        it 'returns true for another regular user trying to edit a wiki post' do
          old_post.wiki = true
          Guardian.new(coding_horror).can_edit?(old_post).should be_true
        end

        it 'returns false when another user has too low trust level to edit wiki post' do
          SiteSetting.stubs(:min_trust_to_edit_wiki_post).returns(2)
          post.wiki = true
          coding_horror.trust_level = 1

          Guardian.new(coding_horror).can_edit?(post).should be_false
        end

        it 'returns true when another user has adequate trust level to edit wiki post' do
          SiteSetting.stubs(:min_trust_to_edit_wiki_post).returns(2)
          post.wiki = true
          coding_horror.trust_level = 2

          Guardian.new(coding_horror).can_edit?(post).should be_true
        end

        it 'returns true for post author even when he has too low trust level to edit wiki post' do
          SiteSetting.stubs(:min_trust_to_edit_wiki_post).returns(2)
          post.wiki = true
          post.user.trust_level = 1

          Guardian.new(post.user).can_edit?(post).should be_true
        end
      end
    end

    describe 'a Topic' do

      it 'returns false when not logged in' do
        Guardian.new.can_edit?(topic).should == false
      end

      it 'returns true for editing your own post' do
        Guardian.new(topic.user).can_edit?(topic).should eq(true)
      end


      it 'returns false as a regular user' do
        Guardian.new(coding_horror).can_edit?(topic).should == false
      end

      context 'not archived' do
        it 'returns true as a moderator' do
          Guardian.new(moderator).can_edit?(topic).should eq(true)
        end

        it 'returns true as an admin' do
          Guardian.new(admin).can_edit?(topic).should eq(true)
        end

        it 'returns true at trust level 3' do
          Guardian.new(leader).can_edit?(topic).should eq(true)
        end
      end

      context 'archived' do
        it 'returns false as a moderator' do
          Guardian.new(moderator).can_edit?(build(:topic, user: user, archived: true)).should == false
        end

        it 'returns false as an admin' do
          Guardian.new(admin).can_edit?(build(:topic, user: user, archived: true)).should == false
        end

        it 'returns false at trust level 3' do
          Guardian.new(leader).can_edit?(build(:topic, user: user, archived: true)).should == false
        end
      end
    end

    describe 'a Category' do

      let(:category) { Fabricate(:category) }

      it 'returns false when not logged in' do
        Guardian.new.can_edit?(category).should be_false
      end

      it 'returns false as a regular user' do
        Guardian.new(category.user).can_edit?(category).should be_false
      end

      it 'returns false as a moderator' do
        Guardian.new(moderator).can_edit?(category).should be_false
      end

      it 'returns true as an admin' do
        Guardian.new(admin).can_edit?(category).should be_true
      end
    end

    describe 'a User' do

      it 'returns false when not logged in' do
        Guardian.new.can_edit?(user).should be_false
      end

      it 'returns false as a different user' do
        Guardian.new(coding_horror).can_edit?(user).should be_false
      end

      it 'returns true when trying to edit yourself' do
        Guardian.new(user).can_edit?(user).should be_true
      end

      it 'returns true as a moderator' do
        Guardian.new(moderator).can_edit?(user).should be_true
      end

      it 'returns true as an admin' do
        Guardian.new(admin).can_edit?(user).should be_true
      end
    end

  end

  context 'can_moderate?' do

    it 'returns false with a nil object' do
      Guardian.new(user).can_moderate?(nil).should be_false
    end

    context 'a Topic' do

      it 'returns false when not logged in' do
        Guardian.new.can_moderate?(topic).should be_false
      end

      it 'returns false when not a moderator' do
        Guardian.new(user).can_moderate?(topic).should be_false
      end

      it 'returns true when a moderator' do
        Guardian.new(moderator).can_moderate?(topic).should be_true
      end

      it 'returns true when an admin' do
        Guardian.new(admin).can_moderate?(topic).should be_true
      end

      it 'returns true when trust level 4' do
        Guardian.new(elder).can_moderate?(topic).should be_true
      end

    end

  end

  context 'can_see_flags?' do

    it "returns false when there is no post" do
      Guardian.new(moderator).can_see_flags?(nil).should be_false
    end

    it "returns false when there is no user" do
      Guardian.new(nil).can_see_flags?(post).should be_false
    end

    it "allow regular users to see flags" do
      Guardian.new(user).can_see_flags?(post).should be_false
    end

    it "allows moderators to see flags" do
      Guardian.new(moderator).can_see_flags?(post).should be_true
    end

    it "allows moderators to see flags" do
      Guardian.new(admin).can_see_flags?(post).should be_true
    end
  end

  context 'can_move_posts?' do

    it 'returns false with a nil object' do
      Guardian.new(user).can_move_posts?(nil).should be_false
    end

    context 'a Topic' do

      it 'returns false when not logged in' do
        Guardian.new.can_move_posts?(topic).should be_false
      end

      it 'returns false when not a moderator' do
        Guardian.new(user).can_move_posts?(topic).should be_false
      end

      it 'returns true when a moderator' do
        Guardian.new(moderator).can_move_posts?(topic).should be_true
      end

      it 'returns true when an admin' do
        Guardian.new(admin).can_move_posts?(topic).should be_true
      end

    end

  end

  context 'can_delete?' do

    it 'returns false with a nil object' do
      Guardian.new(user).can_delete?(nil).should be_false
    end

    context 'a Topic' do
      before do
        # pretend we have a real topic
        topic.id = 9999999
      end

      it 'returns false when not logged in' do
        Guardian.new.can_delete?(topic).should be_false
      end

      it 'returns false when not a moderator' do
        Guardian.new(user).can_delete?(topic).should be_false
      end

      it 'returns true when a moderator' do
        Guardian.new(moderator).can_delete?(topic).should be_true
      end

      it 'returns true when an admin' do
        Guardian.new(admin).can_delete?(topic).should be_true
      end
    end

    context 'a Post' do

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

      context 'post is older than post_edit_time_limit' do
        let(:old_post) { build(:post, topic: topic, user: topic.user, post_number: 2, created_at: 6.minutes.ago) }
        before do
          SiteSetting.stubs(:post_edit_time_limit).returns(5)
        end

        it 'returns false to the author of the post' do
          Guardian.new(old_post.user).can_delete?(old_post).should eq(false)
        end

        it 'returns true as a moderator' do
          Guardian.new(moderator).can_delete?(old_post).should eq(true)
        end

        it 'returns true as an admin' do
          Guardian.new(admin).can_delete?(old_post).should eq(true)
        end

        it "returns false when it's the OP, even as a moderator" do
          old_post.post_number = 1
          Guardian.new(moderator).can_delete?(old_post).should eq(false)
        end

        it 'returns false for another regular user trying to delete your post' do
          Guardian.new(coding_horror).can_delete?(old_post).should eq(false)
        end
      end

      context 'the topic is archived' do
        before do
          post.topic.archived = true
        end

        it "allows a staff member to delete it" do
          Guardian.new(moderator).can_delete?(post).should be_true
        end

        it "doesn't allow a regular user to delete it" do
          Guardian.new(post.user).can_delete?(post).should be_false
        end

      end

    end

    context 'a Category' do

      let(:category) { build(:category, user: moderator) }

      it 'returns false when not logged in' do
        Guardian.new.can_delete?(category).should be_false
      end

      it 'returns false when a regular user' do
        Guardian.new(user).can_delete?(category).should be_false
      end

      it 'returns false when a moderator' do
        Guardian.new(moderator).can_delete?(category).should be_false
      end

      it 'returns true when an admin' do
        Guardian.new(admin).can_delete?(category).should be_true
      end

      it "can't be deleted if it has a forum topic" do
        category.topic_count = 10
        Guardian.new(moderator).can_delete?(category).should be_false
      end

      it "can't be deleted if it is the Uncategorized Category" do
        uncategorized_cat_id = SiteSetting.uncategorized_category_id
        uncategorized_category = Category.find(uncategorized_cat_id)
        Guardian.new(admin).can_delete?(uncategorized_category).should be_false
      end

      it "can't be deleted if it has children" do
        category.expects(:has_children?).returns(true)
        Guardian.new(admin).can_delete?(category).should be_false
      end

    end

    context 'can_suspend?' do
      it 'returns false when a user tries to suspend another user' do
        Guardian.new(user).can_suspend?(coding_horror).should be_false
      end

      it 'returns true when an admin tries to suspend another user' do
        Guardian.new(admin).can_suspend?(coding_horror).should be_true
      end

      it 'returns true when a moderator tries to suspend another user' do
        Guardian.new(moderator).can_suspend?(coding_horror).should be_true
      end

      it 'returns false when staff tries to suspend staff' do
        Guardian.new(admin).can_suspend?(moderator).should be_false
      end
    end

    context 'a PostAction' do
      let(:post_action) {
        user.id = 1
        post.id = 1

        a = PostAction.new(user: user, post: post, post_action_type_id: 1)
        a.created_at = 1.minute.ago
        a
      }

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

  end

  context 'can_approve?' do

    it "wont allow a non-logged in user to approve" do
      Guardian.new.can_approve?(user).should be_false
    end

    it "wont allow a non-admin to approve a user" do
      Guardian.new(coding_horror).can_approve?(user).should be_false
    end

    it "returns false when the user is already approved" do
      user.approved = true
      Guardian.new(admin).can_approve?(user).should be_false
    end

    it "allows an admin to approve a user" do
      Guardian.new(admin).can_approve?(user).should be_true
    end

    it "allows a moderator to approve a user" do
      Guardian.new(moderator).can_approve?(user).should be_true
    end


  end

  context 'can_grant_admin?' do
    it "wont allow a non logged in user to grant an admin's access" do
      Guardian.new.can_grant_admin?(another_admin).should be_false
    end

    it "wont allow a regular user to revoke an admin's access" do
      Guardian.new(user).can_grant_admin?(another_admin).should be_false
    end

    it 'wont allow an admin to grant their own access' do
      Guardian.new(admin).can_grant_admin?(admin).should be_false
    end

    it "allows an admin to grant a regular user access" do
      admin.id = 1
      user.id = 2
      Guardian.new(admin).can_grant_admin?(user).should be_true
    end
  end

  context 'can_revoke_admin?' do
    it "wont allow a non logged in user to revoke an admin's access" do
      Guardian.new.can_revoke_admin?(another_admin).should be_false
    end

    it "wont allow a regular user to revoke an admin's access" do
      Guardian.new(user).can_revoke_admin?(another_admin).should be_false
    end

    it 'wont allow an admin to revoke their own access' do
      Guardian.new(admin).can_revoke_admin?(admin).should be_false
    end

    it "allows an admin to revoke another admin's access" do
      admin.id = 1
      another_admin.id = 2

      Guardian.new(admin).can_revoke_admin?(another_admin).should be_true
    end
  end

  context 'can_grant_moderation?' do

    it "wont allow a non logged in user to grant an moderator's access" do
      Guardian.new.can_grant_moderation?(user).should be_false
    end

    it "wont allow a regular user to revoke an moderator's access" do
      Guardian.new(user).can_grant_moderation?(moderator).should be_false
    end

    it 'will allow an admin to grant their own moderator access' do
      Guardian.new(admin).can_grant_moderation?(admin).should be_true
    end

    it 'wont allow an admin to grant it to an already moderator' do
      Guardian.new(admin).can_grant_moderation?(moderator).should be_false
    end

    it "allows an admin to grant a regular user access" do
      Guardian.new(admin).can_grant_moderation?(user).should be_true
    end
  end

  context 'can_revoke_moderation?' do
    it "wont allow a non logged in user to revoke an moderator's access" do
      Guardian.new.can_revoke_moderation?(moderator).should be_false
    end

    it "wont allow a regular user to revoke an moderator's access" do
      Guardian.new(user).can_revoke_moderation?(moderator).should be_false
    end

    it 'wont allow a moderator to revoke their own moderator' do
      Guardian.new(moderator).can_revoke_moderation?(moderator).should be_false
    end

    it "allows an admin to revoke a moderator's access" do
      Guardian.new(admin).can_revoke_moderation?(moderator).should be_true
    end

    it "allows an admin to revoke a moderator's access from self" do
      admin.moderator = true
      Guardian.new(admin).can_revoke_moderation?(admin).should be_true
    end

    it "does not allow revoke from non moderators" do
      Guardian.new(admin).can_revoke_moderation?(admin).should be_false
    end
  end

  context "can_see_invite_details?" do

    it 'is false without a logged in user' do
      Guardian.new(nil).can_see_invite_details?(user).should be_false
    end

    it 'is false without a user to look at' do
      Guardian.new(user).can_see_invite_details?(nil).should be_false
    end

    it 'is true when looking at your own invites' do
      Guardian.new(user).can_see_invite_details?(user).should be_true
    end
  end

  context "can_access_forum?" do

    let(:unapproved_user) { Fabricate.build(:user) }

    context "when must_approve_users is false" do
      before do
        SiteSetting.stubs(:must_approve_users?).returns(false)
      end

      it "returns true for a nil user" do
        Guardian.new(nil).can_access_forum?.should be_true
      end

      it "returns true for an unapproved user" do
        Guardian.new(unapproved_user).can_access_forum?.should be_true
      end
    end

    context 'when must_approve_users is true' do
      before do
        SiteSetting.stubs(:must_approve_users?).returns(true)
      end

      it "returns false for a nil user" do
        Guardian.new(nil).can_access_forum?.should be_false
      end

      it "returns false for an unapproved user" do
        Guardian.new(unapproved_user).can_access_forum?.should be_false
      end

      it "returns true for an admin user" do
        unapproved_user.admin = true
        Guardian.new(unapproved_user).can_access_forum?.should be_true
      end

      it "returns true for an approved user" do
        unapproved_user.approved = true
        Guardian.new(unapproved_user).can_access_forum?.should be_true
      end

    end

  end

  describe "can_delete_user?" do
    it "is false without a logged in user" do
      Guardian.new(nil).can_delete_user?(user).should == false
    end

    it "is false without a user to look at" do
      Guardian.new(admin).can_delete_user?(nil).should == false
    end

    it "is false for regular users" do
      Guardian.new(user).can_delete_user?(coding_horror).should == false
    end

    context "delete myself" do
      let(:myself) { Fabricate.build(:user, created_at: 6.months.ago) }
      subject      { Guardian.new(myself).can_delete_user?(myself) }

      it "is true to delete myself and I have never made a post" do
        subject.should == true
      end

      it "is true to delete myself and I have only made 1 post" do
        myself.stubs(:post_count).returns(1)
        subject.should == true
      end

      it "is false to delete myself and I have made 2 posts" do
        myself.stubs(:post_count).returns(2)
        subject.should == false
      end
    end

    shared_examples "can_delete_user examples" do
      it "is true if user is not an admin and has never posted" do
        Guardian.new(actor).can_delete_user?(Fabricate.build(:user, created_at: 100.days.ago)).should == true
      end

      it "is true if user is not an admin and first post is not too old" do
        user = Fabricate.build(:user, created_at: 100.days.ago)
        user.stubs(:first_post).returns(Fabricate.build(:post, created_at: 9.days.ago))
        SiteSetting.stubs(:delete_user_max_post_age).returns(10)
        Guardian.new(actor).can_delete_user?(user).should == true
      end

      it "is false if user is an admin" do
        Guardian.new(actor).can_delete_user?(another_admin).should == false
      end

      it "is false if user's first post is too old" do
        user = Fabricate.build(:user, created_at: 100.days.ago)
        user.stubs(:first_post).returns(Fabricate.build(:post, created_at: 11.days.ago))
        SiteSetting.stubs(:delete_user_max_post_age).returns(10)
        Guardian.new(actor).can_delete_user?(user).should == false
      end
    end

    context "for moderators" do
      let(:actor) { moderator }
      include_examples "can_delete_user examples"
    end

    context "for admins" do
      let(:actor) { admin }
      include_examples "can_delete_user examples"
    end
  end

  describe "can_delete_all_posts?" do
    it "is false without a logged in user" do
      Guardian.new(nil).can_delete_all_posts?(user).should be_false
    end

    it "is false without a user to look at" do
      Guardian.new(admin).can_delete_all_posts?(nil).should be_false
    end

    it "is false for regular users" do
      Guardian.new(user).can_delete_all_posts?(coding_horror).should be_false
    end

    shared_examples "can_delete_all_posts examples" do
      it "is true if user has no posts" do
        SiteSetting.stubs(:delete_user_max_post_age).returns(10)
        Guardian.new(actor).can_delete_all_posts?(Fabricate.build(:user, created_at: 100.days.ago)).should be_true
      end

      it "is true if user's first post is newer than delete_user_max_post_age days old" do
        user = Fabricate.build(:user, created_at: 100.days.ago)
        user.stubs(:first_post).returns(Fabricate.build(:post, created_at: 9.days.ago))
        SiteSetting.stubs(:delete_user_max_post_age).returns(10)
        Guardian.new(actor).can_delete_all_posts?(user).should be_true
      end

      it "is false if user's first post is older than delete_user_max_post_age days old" do
        user = Fabricate.build(:user, created_at: 100.days.ago)
        user.stubs(:first_post).returns(Fabricate.build(:post, created_at: 11.days.ago))
        SiteSetting.stubs(:delete_user_max_post_age).returns(10)
        Guardian.new(actor).can_delete_all_posts?(user).should be_false
      end

      it "is false if user is an admin" do
        Guardian.new(actor).can_delete_all_posts?(admin).should be_false
      end

      it "is true if number of posts is small" do
        u = Fabricate.build(:user, created_at: 1.day.ago)
        u.stubs(:post_count).returns(1)
        SiteSetting.stubs(:delete_all_posts_max).returns(10)
        Guardian.new(actor).can_delete_all_posts?(u).should be_true
      end

      it "is false if number of posts is not small" do
        u = Fabricate.build(:user, created_at: 1.day.ago)
        u.stubs(:post_count).returns(11)
        SiteSetting.stubs(:delete_all_posts_max).returns(10)
        Guardian.new(actor).can_delete_all_posts?(u).should be_false
      end
    end

    context "for moderators" do
      let(:actor) { moderator }
      include_examples "can_delete_all_posts examples"
    end

    context "for admins" do
      let(:actor) { admin }
      include_examples "can_delete_all_posts examples"
    end
  end

  describe 'can_grant_title?' do
    it 'is false without a logged in user' do
      Guardian.new(nil).can_grant_title?(user).should be_false
    end

    it 'is false for regular users' do
      Guardian.new(user).can_grant_title?(user).should be_false
    end

    it 'is true for moderators' do
      Guardian.new(moderator).can_grant_title?(user).should be_true
    end

    it 'is true for admins' do
      Guardian.new(admin).can_grant_title?(user).should be_true
    end

    it 'is false without a user to look at' do
      Guardian.new(admin).can_grant_title?(nil).should be_false
    end
  end


  describe 'can_change_trust_level?' do

    it 'is false without a logged in user' do
      Guardian.new(nil).can_change_trust_level?(user).should be_false
    end

    it 'is false for regular users' do
      Guardian.new(user).can_change_trust_level?(user).should be_false
    end

    it 'is true for moderators' do
      Guardian.new(moderator).can_change_trust_level?(user).should be_true
    end

    it 'is true for admins' do
      Guardian.new(admin).can_change_trust_level?(user).should be_true
    end
  end

  describe "can_edit_username?" do
    it "is false without a logged in user" do
      Guardian.new(nil).can_edit_username?(build(:user, created_at: 1.minute.ago)).should be_false
    end

    it "is false for regular users to edit another user's username" do
      Guardian.new(build(:user)).can_edit_username?(build(:user, created_at: 1.minute.ago)).should be_false
    end

    shared_examples "staff can always change usernames" do
      it "is true for moderators" do
        Guardian.new(moderator).can_edit_username?(user).should be_true
      end

      it "is true for admins" do
        Guardian.new(admin).can_edit_username?(user).should be_true
      end
    end

    context 'for a new user' do
      let(:target_user) { build(:user, created_at: 1.minute.ago) }
      include_examples "staff can always change usernames"

      it "is true for the user to change their own username" do
        Guardian.new(target_user).can_edit_username?(target_user).should be_true
      end
    end

    context 'for an old user' do
      before do
        SiteSetting.stubs(:username_change_period).returns(3)
      end

      let(:target_user) { build(:user, created_at: 4.days.ago) }

      context 'with no posts' do
        include_examples "staff can always change usernames"
        it "is true for the user to change their own username" do
          Guardian.new(target_user).can_edit_username?(target_user).should be_true
        end
      end

      context 'with posts' do
        before { target_user.stubs(:post_count).returns(1) }
        include_examples "staff can always change usernames"
        it "is false for the user to change their own username" do
          Guardian.new(target_user).can_edit_username?(target_user).should be_false
        end
      end
    end

    context 'when editing is disabled in preferences' do
      before do
        SiteSetting.stubs(:username_change_period).returns(0)
      end

      include_examples "staff can always change usernames"

      it "is false for the user to change their own username" do
        Guardian.new(user).can_edit_username?(user).should be_false
      end
    end

    context 'when SSO username override is active' do
      before do
        SiteSetting.stubs(:enable_sso).returns(true)
        SiteSetting.stubs(:sso_overrides_username).returns(true)
      end

      it "is false for admins" do
        Guardian.new(admin).can_edit_username?(admin).should be_false
      end

      it "is false for moderators" do
        Guardian.new(moderator).can_edit_username?(moderator).should be_false
      end

      it "is false for users" do
        Guardian.new(user).can_edit_username?(user).should be_false
      end
    end
  end

  describe "can_edit_email?" do
    context 'when allowed in settings' do
      before do
        SiteSetting.stubs(:email_editable?).returns(true)
      end

      it "is false when not logged in" do
        Guardian.new(nil).can_edit_email?(build(:user, created_at: 1.minute.ago)).should be_false
      end

      it "is false for regular users to edit another user's email" do
        Guardian.new(build(:user)).can_edit_email?(build(:user, created_at: 1.minute.ago)).should be_false
      end

      it "is true for a regular user to edit their own email" do
        Guardian.new(user).can_edit_email?(user).should be_true
      end

      it "is true for moderators" do
        Guardian.new(moderator).can_edit_email?(user).should be_true
      end

      it "is true for admins" do
        Guardian.new(admin).can_edit_email?(user).should be_true
      end
    end

    context 'when not allowed in settings' do
      before do
        SiteSetting.stubs(:email_editable?).returns(false)
      end

      it "is false when not logged in" do
        Guardian.new(nil).can_edit_email?(build(:user, created_at: 1.minute.ago)).should be_false
      end

      it "is false for regular users to edit another user's email" do
        Guardian.new(build(:user)).can_edit_email?(build(:user, created_at: 1.minute.ago)).should be_false
      end

      it "is false for a regular user to edit their own email" do
        Guardian.new(user).can_edit_email?(user).should be_false
      end

      it "is true for admins" do
        Guardian.new(admin).can_edit_email?(user).should be_true
      end

      it "is true for moderators" do
        Guardian.new(moderator).can_edit_email?(user).should be_true
      end
    end

    context 'when SSO email override is active' do
      before do
        SiteSetting.stubs(:enable_sso).returns(true)
        SiteSetting.stubs(:sso_overrides_email).returns(true)
      end

      it "is false for admins" do
        Guardian.new(admin).can_edit_email?(admin).should be_false
      end

      it "is false for moderators" do
        Guardian.new(moderator).can_edit_email?(moderator).should be_false
      end

      it "is false for users" do
        Guardian.new(user).can_edit_email?(user).should be_false
      end
    end
  end

  describe 'can_edit_name?' do
    it 'is false without a logged in user' do
      Guardian.new(nil).can_edit_name?(build(:user, created_at: 1.minute.ago)).should be_false
    end

    it "is false for regular users to edit another user's name" do
      Guardian.new(build(:user)).can_edit_name?(build(:user, created_at: 1.minute.ago)).should be_false
    end

    context 'for a new user' do
      let(:target_user) { build(:user, created_at: 1.minute.ago) }

      it 'is true for the user to change their own name' do
        Guardian.new(target_user).can_edit_name?(target_user).should be_true
      end

      it 'is true for moderators' do
        Guardian.new(moderator).can_edit_name?(user).should be_true
      end

      it 'is true for admins' do
        Guardian.new(admin).can_edit_name?(user).should be_true
      end
    end

    context 'when name is disabled in preferences' do
      before do
        SiteSetting.stubs(:enable_names).returns(false)
      end

      it 'is false for the user to change their own name' do
        Guardian.new(user).can_edit_name?(user).should be_false
      end

      it 'is false for moderators' do
        Guardian.new(moderator).can_edit_name?(user).should be_false
      end

      it 'is false for admins' do
        Guardian.new(admin).can_edit_name?(user).should be_false
      end
    end

    context 'when name is enabled in preferences' do
      before do
        SiteSetting.stubs(:enable_names).returns(true)
      end

      context 'when SSO is disabled' do
        before do
          SiteSetting.stubs(:enable_sso).returns(false)
          SiteSetting.stubs(:sso_overrides_name).returns(false)
        end

        it 'is true for admins' do
          Guardian.new(admin).can_edit_name?(admin).should be_true
        end

        it 'is true for moderators' do
          Guardian.new(moderator).can_edit_name?(moderator).should be_true
        end

        it 'is true for users' do
          Guardian.new(user).can_edit_name?(user).should be_true
        end
      end

      context 'when SSO is enabled' do
        before do
          SiteSetting.stubs(:enable_sso).returns(true)
        end

        context 'when SSO name override is active' do
          before do
            SiteSetting.stubs(:sso_overrides_name).returns(true)
          end

          it 'is false for admins' do
            Guardian.new(admin).can_edit_name?(admin).should be_false
          end

          it 'is false for moderators' do
            Guardian.new(moderator).can_edit_name?(moderator).should be_false
          end

          it 'is false for users' do
            Guardian.new(user).can_edit_name?(user).should be_false
          end
        end

        context 'when SSO name override is not active' do
          before do
            SiteSetting.stubs(:sso_overrides_name).returns(false)
          end

          it 'is true for admins' do
            Guardian.new(admin).can_edit_name?(admin).should be_true
          end

          it 'is true for moderators' do
            Guardian.new(moderator).can_edit_name?(moderator).should be_true
          end

          it 'is true for users' do
            Guardian.new(user).can_edit_name?(user).should be_true
          end
        end
      end
    end
  end

  describe 'can_wiki?' do
    it 'returns false for regular user' do
      Guardian.new(coding_horror).can_wiki?.should be_false
    end

    it 'returns true for admin user' do
      Guardian.new(admin).can_wiki?.should be_true
    end

    it 'returns true for elder user' do
      Guardian.new(elder).can_wiki?.should be_true
    end
  end
end
