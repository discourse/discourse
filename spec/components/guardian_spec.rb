require 'rails_helper'

require 'guardian'
require_dependency 'post_destroyer'
require_dependency 'post_locker'

describe Guardian do

  let(:user) { Fabricate(:user) }
  let(:moderator) { Fabricate(:moderator) }
  let(:admin) { Fabricate(:admin) }
  let(:trust_level_2) { build(:user, trust_level: 2) }
  let(:trust_level_3) { build(:user, trust_level: 3) }
  let(:trust_level_4)  { build(:user, trust_level: 4) }
  let(:another_admin) { build(:admin) }
  let(:coding_horror) { build(:coding_horror) }

  let(:topic) { build(:topic, user: user) }
  let(:post) { build(:post, topic: topic, user: topic.user) }

  it 'can be created without a user (not logged in)' do
    expect { Guardian.new }.not_to raise_error
  end

  it 'can be instantiated with a user instance' do
    expect { Guardian.new(user) }.not_to raise_error
  end

  describe "link_posting_access" do
    it "is none for anonymous users" do
      expect(Guardian.new.link_posting_access).to eq('none')
    end

    it "is full for regular users" do
      expect(Guardian.new(user).link_posting_access).to eq('full')
    end

    it "is none for a user of a low trust level" do
      user.trust_level = 0
      SiteSetting.min_trust_to_post_links = 1
      expect(Guardian.new(user).link_posting_access).to eq('none')
    end

    it "is limited for a user of a low trust level with a whitelist" do
      SiteSetting.whitelisted_link_domains = 'example.com'
      user.trust_level = 0
      SiteSetting.min_trust_to_post_links = 1
      expect(Guardian.new(user).link_posting_access).to eq('limited')
    end
  end

  describe "can_post_link?" do
    let(:host) { "discourse.org" }

    it "returns false for anonymous users" do
      expect(Guardian.new.can_post_link?(host: host)).to eq(false)
    end

    it "returns true for a regular user" do
      expect(Guardian.new(user).can_post_link?(host: host)).to eq(true)
    end

    it "supports customization by site setting" do
      user.trust_level = 0
      SiteSetting.min_trust_to_post_links = 0
      expect(Guardian.new(user).can_post_link?(host: host)).to eq(true)
      SiteSetting.min_trust_to_post_links = 1
      expect(Guardian.new(user).can_post_link?(host: host)).to eq(false)
    end

    describe "whitelisted host" do
      before do
        SiteSetting.whitelisted_link_domains = host
      end

      it "allows a new user to post the link to the host" do
        user.trust_level = 0
        SiteSetting.min_trust_to_post_links = 1
        expect(Guardian.new(user).can_post_link?(host: host)).to eq(true)
        expect(Guardian.new(user).can_post_link?(host: 'another-host.com')).to eq(false)
      end
    end
  end

  describe '#post_can_act?' do
    let(:post) { build(:post) }
    let(:user) { build(:user) }

    it "returns false when the user is nil" do
      expect(Guardian.new(nil).post_can_act?(post, :like)).to be_falsey
    end

    it "returns false when the post is nil" do
      expect(Guardian.new(user).post_can_act?(nil, :like)).to be_falsey
    end

    it "returns false when the topic is archived" do
      post.topic.archived = true
      expect(Guardian.new(user).post_can_act?(post, :like)).to be_falsey
    end

    it "returns false when the post is deleted" do
      post.deleted_at = Time.now
      expect(Guardian.new(user).post_can_act?(post, :like)).to be_falsey
    end

    it "works as expected for silenced users" do
      UserSilencer.silence(user, admin)
      expect(Guardian.new(user).post_can_act?(post, :spam)).to be_falsey
      expect(Guardian.new(user).post_can_act?(post, :like)).to be_truthy
      expect(Guardian.new(user).post_can_act?(post, :bookmark)).to be_truthy
    end

    it "allows flagging archived posts" do
      post.topic.archived = true
      expect(Guardian.new(user).post_can_act?(post, :spam)).to be_truthy
    end

    it "does not allow flagging of hidden posts" do
      post.hidden = true
      expect(Guardian.new(user).post_can_act?(post, :spam)).to be_falsey
    end

    it "allows flagging of staff posts when allow_flagging_staff is true" do
      SiteSetting.allow_flagging_staff = true
      staff_post = Fabricate(:post, user: Fabricate(:moderator))
      expect(Guardian.new(user).post_can_act?(staff_post, :spam)).to be_truthy
    end

    describe 'when allow_flagging_staff is false' do
      let(:staff_post) { Fabricate(:post, user: Fabricate(:moderator)) }

      before do
        SiteSetting.allow_flagging_staff = false
      end

      it "doesn't allow flagging of staff posts" do
        expect(Guardian.new(user).post_can_act?(staff_post, :spam)).to eq(false)
      end

      it "allows flagging of staff posts when staff has been deleted" do
        staff_post.user.destroy!
        staff_post.reload
        expect(Guardian.new(user).post_can_act?(staff_post, :spam)).to eq(true)
      end

      it "allows liking of staff" do
        expect(Guardian.new(user).post_can_act?(staff_post, :like)).to eq(true)
      end
    end

    it "returns false when liking yourself" do
      expect(Guardian.new(post.user).post_can_act?(post, :like)).to be_falsey
    end

    it "returns false when you've already done it" do
      expect(Guardian.new(user).post_can_act?(post, :like, opts: {
        taken_actions: { PostActionType.types[:like] => 1 }
      })).to be_falsey
    end

    it "returns false when you already flagged a post" do
      PostActionType.notify_flag_types.each do |type, _id|
        expect(Guardian.new(user).post_can_act?(post, :off_topic, opts: {
          taken_actions: { PostActionType.types[type] => 1 }
        })).to be_falsey
      end
    end

    it "returns false for notify_user if private messages are disabled" do
      SiteSetting.enable_personal_messages = false
      user.trust_level = TrustLevel[2]
      expect(Guardian.new(user).post_can_act?(post, :notify_user)).to be_falsey
    end

    it "returns false for notify_user if private messages are enabled but threshold not met" do
      SiteSetting.enable_personal_messages = true
      SiteSetting.min_trust_to_send_messages = 2
      user.trust_level = TrustLevel[1]
      expect(Guardian.new(user).post_can_act?(post, :notify_user)).to be_falsey
    end

    describe "trust levels" do
      it "returns true for a new user liking something" do
        user.trust_level = TrustLevel[0]
        expect(Guardian.new(user).post_can_act?(post, :like)).to be_truthy
      end

      it "returns false for a new user flagging as spam" do
        user.trust_level = TrustLevel[0]
        expect(Guardian.new(user).post_can_act?(post, :spam)).to be_falsey
      end

      it "returns true for a new user flagging as spam if enabled" do
        SiteSetting.min_trust_to_flag_posts = 0
        user.trust_level = TrustLevel[0]
        expect(Guardian.new(user).post_can_act?(post, :spam)).to be_truthy
      end

      it "returns true for a new user flagging a private message as spam" do
        post = Fabricate(:private_message_post, user: Fabricate(:admin))
        user.trust_level = TrustLevel[0]
        post.topic.allowed_users << user
        expect(Guardian.new(user).post_can_act?(post, :spam)).to be_truthy
      end

      it "returns false for a new user flagging something as off topic" do
        user.trust_level = TrustLevel[0]
        expect(Guardian.new(user).post_can_act?(post, :off_topic)).to be_falsey
      end

      it "returns false for a new user flagging with notify_user" do
        user.trust_level = TrustLevel[0]
        expect(Guardian.new(user).post_can_act?(post, :notify_user)).to be_falsey # because new users can't send private messages
      end
    end
  end

  describe "can_enable_safe_mode" do
    let(:user) { Fabricate.build(:user) }
    let(:moderator) { Fabricate.build(:moderator) }

    context "when enabled" do
      before do
        SiteSetting.enable_safe_mode = true
      end

      it "can be performed" do
        expect(Guardian.new.can_enable_safe_mode?).to eq(true)
        expect(Guardian.new(user).can_enable_safe_mode?).to eq(true)
        expect(Guardian.new(moderator).can_enable_safe_mode?).to eq(true)
      end
    end

    context "when disabled" do
      before do
        SiteSetting.enable_safe_mode = false
      end

      it "can be performed" do
        expect(Guardian.new.can_enable_safe_mode?).to eq(false)
        expect(Guardian.new(user).can_enable_safe_mode?).to eq(false)
        expect(Guardian.new(moderator).can_enable_safe_mode?).to eq(true)
      end
    end
  end

  describe "can_defer_flags" do
    let(:post) { Fabricate(:post) }
    let(:user) { post.user }
    let(:moderator) { Fabricate(:moderator) }

    it "returns false when the user is nil" do
      expect(Guardian.new(nil).can_defer_flags?(post)).to be_falsey
    end

    it "returns false when the post is nil" do
      expect(Guardian.new(moderator).can_defer_flags?(nil)).to be_falsey
    end

    it "returns false when the user is not a moderator" do
      expect(Guardian.new(user).can_defer_flags?(post)).to be_falsey
    end

    it "returns true when the user is a moderator" do
      expect(Guardian.new(moderator).can_defer_flags?(post)).to be_truthy
    end

  end

  describe 'can_send_private_message' do
    let(:user) { Fabricate(:user) }
    let(:another_user) { Fabricate(:user) }
    let(:suspended_user) { Fabricate(:user, suspended_till: 1.week.from_now, suspended_at: 1.day.ago) }

    it "returns false when the user is nil" do
      expect(Guardian.new(nil).can_send_private_message?(user)).to be_falsey
    end

    it "returns false when the target user is nil" do
      expect(Guardian.new(user).can_send_private_message?(nil)).to be_falsey
    end

    it "returns true when the target is the same as the user" do
      # this is now allowed so yay
      expect(Guardian.new(user).can_send_private_message?(user)).to be_truthy
    end

    it "returns false when you are untrusted" do
      user.trust_level = TrustLevel[0]
      expect(Guardian.new(user).can_send_private_message?(another_user)).to be_falsey
    end

    it "returns true to another user" do
      expect(Guardian.new(user).can_send_private_message?(another_user)).to be_truthy
    end

    it "disallows pms to other users if trust level is not met" do
      SiteSetting.min_trust_to_send_messages = TrustLevel[2]
      user.trust_level = TrustLevel[1]
      expect(Guardian.new(user).can_send_private_message?(another_user)).to be_falsey
    end

    context "enable_personal_messages is false" do
      before { SiteSetting.enable_personal_messages = false }

      it "returns false if user is not staff member" do
        expect(Guardian.new(trust_level_4).can_send_private_message?(another_user)).to be_falsey
      end

      it "returns true for staff member" do
        expect(Guardian.new(moderator).can_send_private_message?(another_user)).to be_truthy
        expect(Guardian.new(admin).can_send_private_message?(another_user)).to be_truthy
      end
    end

    context "target user is suspended" do
      it "returns true for staff" do
        expect(Guardian.new(admin).can_send_private_message?(suspended_user)).to be_truthy
        expect(Guardian.new(moderator).can_send_private_message?(suspended_user)).to be_truthy
      end

      it "returns false for regular users" do
        expect(Guardian.new(user).can_send_private_message?(suspended_user)).to be_falsey
      end
    end

    context "author is silenced" do
      before do
        user.silenced_till = 1.year.from_now
        user.save
      end

      it "returns true if target is staff" do
        expect(Guardian.new(user).can_send_private_message?(admin)).to be_truthy
        expect(Guardian.new(user).can_send_private_message?(moderator)).to be_truthy
      end

      it "returns false if target is not staff" do
        expect(Guardian.new(user).can_send_private_message?(another_user)).to be_falsey
      end

      it "returns true if target is a staff group" do
        Group::STAFF_GROUPS.each do |name|
          g = Group[name]
          g.update!(messageable_level: Group::ALIAS_LEVELS[:everyone])
          expect(Guardian.new(user).can_send_private_message?(g)).to be_truthy
        end
      end
    end

    it "respects the group's messageable_level" do
      group = Fabricate(:group)

      Group::ALIAS_LEVELS.each do |level, _|
        group.update!(messageable_level: Group::ALIAS_LEVELS[level])
        output = level == :everyone ? true : false

        expect(Guardian.new(user).can_send_private_message?(group)).to eq(output)
      end

      admin = Fabricate(:admin)

      Group::ALIAS_LEVELS.each do |level, _|
        group.update!(messageable_level: Group::ALIAS_LEVELS[level])
        expect(Guardian.new(admin).can_send_private_message?(group)).to eq(true)
      end
    end

    context 'target user has private message disabled' do
      before do
        another_user.user_option.update!(allow_private_messages: false)
      end

      context 'for a normal user' do
        it 'should return false' do
          expect(Guardian.new(user).can_send_private_message?(another_user)).to eq(false)
        end
      end

      context 'for a staff user' do
        it 'should return true' do
          [admin, moderator].each do |staff_user|
            expect(Guardian.new(staff_user).can_send_private_message?(another_user))
              .to eq(true)
          end
        end
      end
    end
  end

  describe 'can_reply_as_new_topic' do
    let(:user) { Fabricate(:user) }
    let(:topic) { Fabricate(:topic) }
    let(:private_message) { Fabricate(:private_message_topic) }

    it "returns false for a non logged in user" do
      expect(Guardian.new(nil).can_reply_as_new_topic?(topic)).to be_falsey
    end

    it "returns false for a nil topic" do
      expect(Guardian.new(user).can_reply_as_new_topic?(nil)).to be_falsey
    end

    it "returns false for an untrusted user" do
      user.trust_level = TrustLevel[0]
      expect(Guardian.new(user).can_reply_as_new_topic?(topic)).to be_falsey
    end

    it "returns true for a trusted user" do
      expect(Guardian.new(user).can_reply_as_new_topic?(topic)).to be_truthy
    end

    it "returns true for a private message" do
      expect(Guardian.new(user).can_reply_as_new_topic?(private_message)).to be_truthy
    end
  end

  describe 'can_see_post_actors?' do

    let(:topic) { Fabricate(:topic, user: coding_horror) }

    it 'displays visibility correctly' do
      guardian = Guardian.new(user)
      expect(guardian.can_see_post_actors?(nil, PostActionType.types[:like])).to be_falsey
      expect(guardian.can_see_post_actors?(topic, PostActionType.types[:like])).to be_truthy
      expect(guardian.can_see_post_actors?(topic, PostActionType.types[:bookmark])).to be_falsey
      expect(guardian.can_see_post_actors?(topic, PostActionType.types[:off_topic])).to be_falsey
      expect(guardian.can_see_post_actors?(topic, PostActionType.types[:spam])).to be_falsey
      expect(guardian.can_see_post_actors?(topic, PostActionType.types[:notify_user])).to be_falsey

      expect(Guardian.new(moderator).can_see_post_actors?(topic, PostActionType.types[:notify_user])).to be_truthy
    end

  end

  describe 'can_impersonate?' do
    it 'allows impersonation correctly' do
      expect(Guardian.new(admin).can_impersonate?(nil)).to be_falsey
      expect(Guardian.new.can_impersonate?(user)).to be_falsey
      expect(Guardian.new(coding_horror).can_impersonate?(user)).to be_falsey
      expect(Guardian.new(admin).can_impersonate?(admin)).to be_falsey
      expect(Guardian.new(admin).can_impersonate?(another_admin)).to be_falsey
      expect(Guardian.new(admin).can_impersonate?(user)).to be_truthy
      expect(Guardian.new(admin).can_impersonate?(moderator)).to be_truthy

      Rails.configuration.stubs(:developer_emails).returns([admin.email])
      expect(Guardian.new(admin).can_impersonate?(another_admin)).to be_truthy
    end
  end

  describe "can_view_action_logs?" do
    it 'is false for non-staff acting user' do
      expect(Guardian.new(user).can_view_action_logs?(moderator)).to be_falsey
    end

    it 'is false without a target user' do
      expect(Guardian.new(moderator).can_view_action_logs?(nil)).to be_falsey
    end

    it 'is true when target user is present' do
      expect(Guardian.new(moderator).can_view_action_logs?(user)).to be_truthy
    end
  end

  describe 'can_invite_to_forum?' do
    let(:user) { Fabricate.build(:user) }
    let(:moderator) { Fabricate.build(:moderator) }

    it "doesn't allow anonymous users to invite" do
      expect(Guardian.new.can_invite_to_forum?).to be_falsey
    end

    it 'returns true when the site requires approving users and is mod' do
      SiteSetting.must_approve_users = true
      expect(Guardian.new(moderator).can_invite_to_forum?).to be_truthy
    end

    it 'returns false when max_invites_per_day is 0' do
      # let's also break it while here
      SiteSetting.max_invites_per_day = "a"

      expect(Guardian.new(user).can_invite_to_forum?).to be_falsey
      # staff should be immune to max_invites_per_day setting
      expect(Guardian.new(moderator).can_invite_to_forum?).to be_truthy
    end

    it 'returns false when the site requires approving users and is regular' do
      SiteSetting.expects(:must_approve_users?).returns(true)
      expect(Guardian.new(user).can_invite_to_forum?).to be_falsey
    end

    it 'returns false when the local logins are disabled' do
      SiteSetting.enable_local_logins = false
      expect(Guardian.new(user).can_invite_to_forum?).to be_falsey
      expect(Guardian.new(moderator).can_invite_to_forum?).to be_falsey
    end

    context 'with groups' do
      let(:group) { Fabricate(:group) }
      let(:another_group) { Fabricate(:group) }
      let(:groups) { [group, another_group] }

      before do
        user.update!(trust_level: TrustLevel[2])
        group.add_owner(user)
      end

      it 'returns false when user is not allowed to edit a group' do
        expect(Guardian.new(user).can_invite_to_forum?(groups)).to eq(false)

        expect(Guardian.new(Fabricate(:admin)).can_invite_to_forum?(groups))
          .to eq(true)
      end

      it 'returns true when user is allowed to edit groups' do
        another_group.add_owner(user)

        expect(Guardian.new(user).can_invite_to_forum?(groups)).to eq(true)
      end
    end
  end

  describe 'can_invite_to?' do

    describe "regular topics" do
      let(:group) { Fabricate(:group) }
      let(:category) { Fabricate(:category, read_restricted: true) }
      let(:topic) { Fabricate(:topic) }
      let(:private_topic) { Fabricate(:topic, category: category) }
      let(:user) { topic.user }
      let(:moderator) { Fabricate(:moderator) }
      let(:admin) { Fabricate(:admin) }
      let(:private_category)  { Fabricate(:private_category, group: group) }
      let(:group_private_topic) { Fabricate(:topic, category: private_category) }
      let(:group_owner) { group_private_topic.user.tap { |u| group.add_owner(u) } }
      let(:pm) { Fabricate(:topic) }

      it 'handles invitation correctly' do
        expect(Guardian.new(nil).can_invite_to?(topic)).to be_falsey
        expect(Guardian.new(moderator).can_invite_to?(nil)).to be_falsey
        expect(Guardian.new(moderator).can_invite_to?(topic)).to be_truthy
        expect(Guardian.new(user).can_invite_to?(topic)).to be_falsey

        SiteSetting.max_invites_per_day = 0

        expect(Guardian.new(user).can_invite_to?(topic)).to be_falsey
        # staff should be immune to max_invites_per_day setting
        expect(Guardian.new(moderator).can_invite_to?(topic)).to be_truthy
      end

      it 'returns false for normal user on private topic' do
        expect(Guardian.new(user).can_invite_to?(private_topic)).to be_falsey
      end

      it 'returns false for admin on private topic' do
        expect(Guardian.new(admin).can_invite_to?(private_topic)).to be(false)
      end

      it 'returns true for a group owner' do
        expect(Guardian.new(group_owner).can_invite_to?(group_private_topic)).to be_truthy
      end

      it 'returns true for normal user when inviting to topic and PM disabled' do
        SiteSetting.enable_personal_messages = false
        expect(Guardian.new(trust_level_2).can_invite_to?(topic)).to be_truthy
      end

      describe 'for a private category for automatic and non-automatic group' do
        let(:automatic_group) { Fabricate(:group, automatic: true) }
        let(:group) { Fabricate(:group) }

        let(:category) do
          Fabricate(:category, read_restricted: true).tap do |category|
            category.groups << automatic_group
            category.groups << group
          end
        end

        let(:topic) { Fabricate(:topic, category: category) }

        it 'should return true for an admin user' do
          expect(Guardian.new(admin).can_invite_to?(topic)).to eq(true)
        end

        it 'should return true for a group owner' do
          expect(Guardian.new(group_owner).can_invite_to?(topic)).to eq(true)
        end

        it 'should return false for a normal user' do
          expect(Guardian.new(user).can_invite_to?(topic)).to eq(false)
        end
      end

      describe 'for a private category for automatic groups' do
        let(:group) { Fabricate(:group, automatic: true) }

        let(:category) do
          Fabricate(:private_category, group: group, read_restricted: true)
        end

        let(:group_owner) { Fabricate(:user).tap { |user| group.add_owner(user) } }
        let(:topic) { Fabricate(:topic, category: category) }

        it 'should return false for all type of users' do
          expect(Guardian.new(admin).can_invite_to?(topic)).to eq(false)
          expect(Guardian.new(group_owner).can_invite_to?(topic)).to eq(false)
          expect(Guardian.new(user).can_invite_to?(topic)).to eq(false)
        end
      end
    end

    describe "private messages" do
      let(:user) { Fabricate(:user, trust_level: TrustLevel[2]) }
      let!(:pm) { Fabricate(:private_message_topic, user: user) }
      let(:admin) { Fabricate(:admin) }
      let(:moderator) { Fabricate(:moderator) }

      context "when private messages are disabled" do
        it "allows an admin to invite to the pm" do
          expect(Guardian.new(admin).can_invite_to?(pm)).to be_truthy
          expect(Guardian.new(user).can_invite_to?(pm)).to be_truthy
        end
      end

      context "when private messages are disabled" do
        before do
          SiteSetting.enable_personal_messages = false
        end

        it "doesn't allow a regular user to invite" do
          expect(Guardian.new(admin).can_invite_to?(pm)).to be_truthy
          expect(Guardian.new(user).can_invite_to?(pm)).to be_falsey
        end
      end

      context "when PM has receached the maximum number of recipients" do
        before do
          SiteSetting.max_allowed_message_recipients = 2
        end

        it "doesn't allow a regular user to invite" do
          expect(Guardian.new(user).can_invite_to?(pm)).to be_falsey
        end

        it "allows staff to invite" do
          expect(Guardian.new(admin).can_invite_to?(pm)).to be_truthy
          pm.grant_permission_to_user(moderator.email)
          expect(Guardian.new(moderator).can_invite_to?(pm)).to be_truthy
        end
      end
    end
  end

  describe 'can_invite_via_email?' do
    it 'returns true for all (tl2 and above) users when sso is disabled, local logins are enabled, user approval is not required' do
      expect(Guardian.new(trust_level_2).can_invite_via_email?(topic)).to be_truthy
      expect(Guardian.new(moderator).can_invite_via_email?(topic)).to be_truthy
      expect(Guardian.new(admin).can_invite_via_email?(topic)).to be_truthy
    end

    it 'returns false for all users when sso is enabled' do
      SiteSetting.sso_url = "https://www.example.com/sso"
      SiteSetting.enable_sso = true

      expect(Guardian.new(trust_level_2).can_invite_via_email?(topic)).to be_falsey
      expect(Guardian.new(moderator).can_invite_via_email?(topic)).to be_falsey
      expect(Guardian.new(admin).can_invite_via_email?(topic)).to be_falsey
    end

    it 'returns false for all users when local logins are disabled' do
      SiteSetting.enable_local_logins = false

      expect(Guardian.new(trust_level_2).can_invite_via_email?(topic)).to be_falsey
      expect(Guardian.new(moderator).can_invite_via_email?(topic)).to be_falsey
      expect(Guardian.new(admin).can_invite_via_email?(topic)).to be_falsey
    end

    it 'returns correct valuse when user approval is required' do
      SiteSetting.must_approve_users = true

      expect(Guardian.new(trust_level_2).can_invite_via_email?(topic)).to be_falsey
      expect(Guardian.new(moderator).can_invite_via_email?(topic)).to be_truthy
      expect(Guardian.new(admin).can_invite_via_email?(topic)).to be_truthy
    end
  end

  describe 'can_see?' do

    it 'returns false with a nil object' do
      expect(Guardian.new.can_see?(nil)).to be_falsey
    end

    describe 'a Category' do

      it 'allows public categories' do
        public_category = build(:category, read_restricted: false)
        expect(Guardian.new.can_see?(public_category)).to be_truthy
      end

      it 'correctly handles secure categories' do
        normal_user = build(:user)
        staged_user = build(:user, staged: true)
        admin_user  = build(:user, admin: true)

        secure_category = build(:category, read_restricted: true)
        expect(Guardian.new(normal_user).can_see?(secure_category)).to be_falsey
        expect(Guardian.new(staged_user).can_see?(secure_category)).to be_falsey
        expect(Guardian.new(admin_user).can_see?(secure_category)).to be_truthy

        secure_category = build(:category, read_restricted: true, email_in: "foo@bar.com")
        expect(Guardian.new(normal_user).can_see?(secure_category)).to be_falsey
        expect(Guardian.new(staged_user).can_see?(secure_category)).to be_falsey
        expect(Guardian.new(admin_user).can_see?(secure_category)).to be_truthy

        secure_category = build(:category, read_restricted: true, email_in_allow_strangers: true)
        expect(Guardian.new(normal_user).can_see?(secure_category)).to be_falsey
        expect(Guardian.new(staged_user).can_see?(secure_category)).to be_falsey
        expect(Guardian.new(admin_user).can_see?(secure_category)).to be_truthy

        secure_category = build(:category, read_restricted: true, email_in: "foo@bar.com", email_in_allow_strangers: true)
        expect(Guardian.new(normal_user).can_see?(secure_category)).to be_falsey
        expect(Guardian.new(staged_user).can_see?(secure_category)).to be_truthy
        expect(Guardian.new(admin_user).can_see?(secure_category)).to be_truthy
      end

      it 'allows members of an authorized group' do
        user = Fabricate(:user)
        group = Fabricate(:group)

        secure_category = Fabricate(:category)
        secure_category.set_permissions(group => :readonly)
        secure_category.save

        expect(Guardian.new(user).can_see?(secure_category)).to be_falsey

        group.add(user)
        group.save

        expect(Guardian.new(user).can_see?(secure_category)).to be_truthy
      end

    end

    describe 'a Topic' do
      it 'allows non logged in users to view topics' do
        expect(Guardian.new.can_see?(topic)).to be_truthy
      end

      it 'correctly handles groups' do
        group = Fabricate(:group)
        category = Fabricate(:category, read_restricted: true)
        category.set_permissions(group => :full)
        category.save

        topic = Fabricate(:topic, category: category)

        expect(Guardian.new(user).can_see?(topic)).to be_falsey
        group.add(user)
        group.save

        expect(Guardian.new(user).can_see?(topic)).to be_truthy
      end

      it "restricts deleted topics" do
        topic = Fabricate(:topic)
        topic.trash!(moderator)

        expect(Guardian.new(build(:user)).can_see?(topic)).to be_falsey
        expect(Guardian.new(moderator).can_see?(topic)).to be_truthy
        expect(Guardian.new(admin).can_see?(topic)).to be_truthy
      end

      it "restricts private topics" do
        user.save!
        private_topic = Fabricate(:private_message_topic, user: user)
        expect(Guardian.new(private_topic.user).can_see?(private_topic)).to be_truthy
        expect(Guardian.new(build(:user)).can_see?(private_topic)).to be_falsey
        expect(Guardian.new(moderator).can_see?(private_topic)).to be_falsey
        expect(Guardian.new(admin).can_see?(private_topic)).to be_truthy
      end

      it "restricts private deleted topics" do
        user.save!
        private_topic = Fabricate(:private_message_topic, user: user)
        private_topic.trash!(admin)

        expect(Guardian.new(private_topic.user).can_see?(private_topic)).to be_falsey
        expect(Guardian.new(build(:user)).can_see?(private_topic)).to be_falsey
        expect(Guardian.new(moderator).can_see?(private_topic)).to be_falsey
        expect(Guardian.new(admin).can_see?(private_topic)).to be_truthy
      end

      it "restricts static doc topics" do
        tos_topic = Fabricate(:topic, user: Discourse.system_user)
        SiteSetting.tos_topic_id = tos_topic.id

        expect(Guardian.new(build(:user)).can_edit?(tos_topic)).to be_falsey
        expect(Guardian.new(moderator).can_edit?(tos_topic)).to be_falsey
        expect(Guardian.new(admin).can_edit?(tos_topic)).to be_truthy
      end

      it "allows moderators to see a flagged private message" do
        moderator.save!
        user.save!

        private_topic = Fabricate(:private_message_topic, user: user)
        first_post = Fabricate(:post, topic: private_topic, user: user)

        expect(Guardian.new(moderator).can_see?(private_topic)).to be_falsey

        PostActionCreator.create(user, first_post, :off_topic)
        expect(Guardian.new(moderator).can_see?(private_topic)).to be_truthy
      end
    end

    describe 'a Post' do
      let(:another_admin) { Fabricate(:admin) }
      it 'correctly handles post visibility' do
        post = Fabricate(:post)
        topic = post.topic

        expect(Guardian.new(user).can_see?(post)).to be_truthy

        post.trash!(another_admin)
        post.reload
        expect(Guardian.new(user).can_see?(post)).to be_falsey
        expect(Guardian.new(admin).can_see?(post)).to be_truthy

        post.recover!
        post.reload
        topic.trash!(another_admin)
        topic.reload
        expect(Guardian.new(user).can_see?(post)).to be_falsey
        expect(Guardian.new(admin).can_see?(post)).to be_truthy
      end

      it 'respects whispers' do
        regular_post = Fabricate.build(:post)
        whisper_post = Fabricate.build(:post, post_type: Post.types[:whisper])

        anon_guardian = Guardian.new
        expect(anon_guardian.can_see?(regular_post)).to eq(true)
        expect(anon_guardian.can_see?(whisper_post)).to eq(false)

        regular_user = Fabricate.build(:user)
        regular_guardian = Guardian.new(regular_user)
        expect(regular_guardian.can_see?(regular_post)).to eq(true)
        expect(regular_guardian.can_see?(whisper_post)).to eq(false)

        # can see your own whispers
        regular_whisper = Fabricate.build(:post, post_type: Post.types[:whisper], user: regular_user)
        expect(regular_guardian.can_see?(regular_whisper)).to eq(true)

        mod_guardian = Guardian.new(Fabricate.build(:moderator))
        expect(mod_guardian.can_see?(regular_post)).to eq(true)
        expect(mod_guardian.can_see?(whisper_post)).to eq(true)

        admin_guardian = Guardian.new(Fabricate.build(:admin))
        expect(admin_guardian.can_see?(regular_post)).to eq(true)
        expect(admin_guardian.can_see?(whisper_post)).to eq(true)
      end
    end

    describe 'a PostRevision' do
      let(:post_revision) { Fabricate(:post_revision) }

      context 'edit_history_visible_to_public is true' do
        before { SiteSetting.edit_history_visible_to_public = true }

        it 'is false for nil' do
          expect(Guardian.new.can_see?(nil)).to be_falsey
        end

        it 'is true if not logged in' do
          expect(Guardian.new.can_see?(post_revision)).to be_truthy
        end

        it 'is true when logged in' do
          expect(Guardian.new(Fabricate(:user)).can_see?(post_revision)).to be_truthy
        end
      end

      context 'edit_history_visible_to_public is false' do
        before { SiteSetting.edit_history_visible_to_public = false }

        it 'is true for staff' do
          expect(Guardian.new(Fabricate(:admin)).can_see?(post_revision)).to be_truthy
          expect(Guardian.new(Fabricate(:moderator)).can_see?(post_revision)).to be_truthy
        end

        it 'is true for trust level 4' do
          expect(Guardian.new(trust_level_4).can_see?(post_revision)).to be_truthy
        end

        it 'is false for trust level lower than 4' do
          expect(Guardian.new(trust_level_3).can_see?(post_revision)).to be_falsey
        end
      end
    end
  end

  describe 'can_create?' do

    describe 'a Category' do

      it 'returns false when not logged in' do
        expect(Guardian.new.can_create?(Category)).to be_falsey
      end

      it 'returns false when a regular user' do
        expect(Guardian.new(user).can_create?(Category)).to be_falsey
      end

      it 'returns false when a moderator' do
        expect(Guardian.new(moderator).can_create?(Category)).to be_falsey
      end

      it 'returns true when an admin' do
        expect(Guardian.new(admin).can_create?(Category)).to be_truthy
      end
    end

    describe 'a Topic' do
      it 'does not allow moderators to create topics in readonly categories' do
        category = Fabricate(:category)
        category.set_permissions(everyone: :read)
        category.save

        expect(Guardian.new(moderator).can_create?(Topic, category)).to be_falsey
      end

      it 'should check for full permissions' do
        category = Fabricate(:category)
        category.set_permissions(everyone: :create_post)
        category.save
        expect(Guardian.new(user).can_create?(Topic, category)).to be_falsey
      end

      it "is true for new users by default" do
        expect(Guardian.new(user).can_create?(Topic, Fabricate(:category))).to be_truthy
      end

      it "is false if user has not met minimum trust level" do
        SiteSetting.min_trust_to_create_topic = 1
        expect(Guardian.new(build(:user, trust_level: 0)).can_create?(Topic, Fabricate(:category))).to be_falsey
      end

      it "is true if user has met or exceeded the minimum trust level" do
        SiteSetting.min_trust_to_create_topic = 1
        expect(Guardian.new(build(:user, trust_level: 1)).can_create?(Topic, Fabricate(:category))).to be_truthy
        expect(Guardian.new(build(:user, trust_level: 2)).can_create?(Topic, Fabricate(:category))).to be_truthy
        expect(Guardian.new(build(:admin, trust_level: 0)).can_create?(Topic, Fabricate(:category))).to be_truthy
        expect(Guardian.new(build(:moderator, trust_level: 0)).can_create?(Topic, Fabricate(:category))).to be_truthy
      end
    end

    describe 'a Post' do

      it "is false on readonly categories" do
        category = Fabricate(:category)
        topic.category = category
        category.set_permissions(everyone: :readonly)
        category.save

        expect(Guardian.new(topic.user).can_create?(Post, topic)).to be_falsey
        expect(Guardian.new(moderator).can_create?(Post, topic)).to be_falsey
      end

      it "is false when not logged in" do
        expect(Guardian.new.can_create?(Post, topic)).to be_falsey
      end

      it 'is true for a regular user' do
        expect(Guardian.new(topic.user).can_create?(Post, topic)).to be_truthy
      end

      it "is false when you can't see the topic" do
        Guardian.any_instance.expects(:can_see?).with(topic).returns(false)
        expect(Guardian.new(topic.user).can_create?(Post, topic)).to be_falsey
      end

      context 'closed topic' do
        before do
          topic.closed = true
        end

        it "doesn't allow new posts from regular users" do
          expect(Guardian.new(topic.user).can_create?(Post, topic)).to be_falsey
        end

        it 'allows editing of posts' do
          expect(Guardian.new(topic.user).can_edit?(post)).to be_truthy
        end

        it "allows new posts from moderators" do
          expect(Guardian.new(moderator).can_create?(Post, topic)).to be_truthy
        end

        it "allows new posts from admins" do
          expect(Guardian.new(admin).can_create?(Post, topic)).to be_truthy
        end

        it "allows new posts from trust_level_4s" do
          expect(Guardian.new(trust_level_4).can_create?(Post, topic)).to be_truthy
        end
      end

      context 'archived topic' do
        before do
          topic.archived = true
        end

        context 'regular users' do
          it "doesn't allow new posts from regular users" do
            expect(Guardian.new(coding_horror).can_create?(Post, topic)).to be_falsey
          end

          it 'does not allow editing of posts' do
            expect(Guardian.new(coding_horror).can_edit?(post)).to be_falsey
          end
        end

        it "allows new posts from moderators" do
          expect(Guardian.new(moderator).can_create?(Post, topic)).to be_truthy
        end

        it "allows new posts from admins" do
          expect(Guardian.new(admin).can_create?(Post, topic)).to be_truthy
        end
      end

      context "trashed topic" do
        before do
          topic.deleted_at = Time.now
        end

        it "doesn't allow new posts from regular users" do
          expect(Guardian.new(coding_horror).can_create?(Post, topic)).to be_falsey
        end

        it "doesn't allow new posts from moderators users" do
          expect(Guardian.new(moderator).can_create?(Post, topic)).to be_falsey
        end

        it "doesn't allow new posts from admins" do
          expect(Guardian.new(admin).can_create?(Post, topic)).to be_falsey
        end
      end

      context "system message" do
        let(:private_message) {
          Fabricate(
            :topic,
            archetype: Archetype.private_message,
            subtype: 'system_message',
            category_id: nil
          )
        }

        before { user.save! }
        it "allows the user to reply to system messages" do
          expect(Guardian.new(user).can_create_post?(private_message)).to eq(true)
          SiteSetting.enable_system_message_replies = false
          expect(Guardian.new(user).can_create_post?(private_message)).to eq(false)
        end

      end

      context "private message" do
        let(:private_message) { Fabricate(:topic, archetype: Archetype.private_message, category_id: nil) }

        before { user.save! }

        it "allows new posts by people included in the pm" do
          private_message.topic_allowed_users.create!(user_id: user.id)
          expect(Guardian.new(user).can_create?(Post, private_message)).to be_truthy
        end

        it "doesn't allow new posts by people not invited to the pm" do
          expect(Guardian.new(user).can_create?(Post, private_message)).to be_falsey
        end

        it "allows new posts from silenced users included in the pm" do
          user.update_attribute(:silenced_till, 1.year.from_now)
          private_message.topic_allowed_users.create!(user_id: user.id)
          expect(Guardian.new(user).can_create?(Post, private_message)).to be_truthy
        end

        it "doesn't allow new posts from silenced users not invited to the pm" do
          user.update_attribute(:silenced_till, 1.year.from_now)
          expect(Guardian.new(user).can_create?(Post, private_message)).to be_falsey
        end
      end
    end # can_create? a Post

  end

  describe 'post_can_act?' do

    it "isn't allowed on nil" do
      expect(Guardian.new(user).post_can_act?(nil, nil)).to be_falsey
    end

    describe 'a Post' do

      let (:guardian) do
        Guardian.new(user)
      end

      it "isn't allowed when not logged in" do
        expect(Guardian.new(nil).post_can_act?(post, :vote)).to be_falsey
      end

      it "is allowed as a regular user" do
        expect(guardian.post_can_act?(post, :vote)).to be_truthy
      end

      it "isn't allowed on archived topics" do
        topic.archived = true
        expect(Guardian.new(user).post_can_act?(post, :like)).to be_falsey
      end
    end
  end

  describe "can_recover_topic?" do

    it "returns false for a nil user" do
      expect(Guardian.new(nil).can_recover_topic?(topic)).to be_falsey
    end

    it "returns false for a nil object" do
      expect(Guardian.new(user).can_recover_topic?(nil)).to be_falsey
    end

    it "returns false for a regular user" do
      expect(Guardian.new(user).can_recover_topic?(topic)).to be_falsey
    end

    context 'as a moderator' do
      before do
        topic.save!
        post.save!
      end

      describe 'when post has been deleted' do
        it "should return the right value" do
          expect(Guardian.new(moderator).can_recover_topic?(topic)).to be_falsey

          PostDestroyer.new(moderator, topic.first_post).destroy

          expect(Guardian.new(moderator).can_recover_topic?(topic.reload)).to be_truthy
        end
      end

      describe "when post's user has been deleted" do
        it 'should return the right value' do
          PostDestroyer.new(moderator, topic.first_post).destroy
          topic.first_post.user.destroy!

          expect(Guardian.new(moderator).can_recover_topic?(topic.reload)).to be_falsey
        end
      end
    end
  end

  describe "can_recover_post?" do

    it "returns false for a nil user" do
      expect(Guardian.new(nil).can_recover_post?(post)).to be_falsey
    end

    it "returns false for a nil object" do
      expect(Guardian.new(user).can_recover_post?(nil)).to be_falsey
    end

    it "returns false for a regular user" do
      expect(Guardian.new(user).can_recover_post?(post)).to be_falsey
    end

    context 'as a moderator' do
      let(:other_post) { Fabricate(:post, topic: topic, user: topic.user) }

      before do
        topic.save!
        post.save!
      end

      describe 'when post has been deleted' do
        it "should return the right value" do
          expect(Guardian.new(moderator).can_recover_post?(post)).to be_falsey

          PostDestroyer.new(moderator, post).destroy

          expect(Guardian.new(moderator).can_recover_post?(post.reload)).to be_truthy
        end

        describe "when post's user has been deleted" do
          it 'should return the right value' do
            PostDestroyer.new(moderator, post).destroy
            post.user.destroy!

            expect(Guardian.new(moderator).can_recover_post?(post.reload)).to be_falsey
          end
        end
      end
    end

  end

  context 'can_convert_topic?' do
    it 'returns false with a nil object' do
      expect(Guardian.new(user).can_convert_topic?(nil)).to be_falsey
    end

    it 'returns false when not logged in' do
      expect(Guardian.new.can_convert_topic?(topic)).to be_falsey
    end

    it 'returns false when not staff' do
      expect(Guardian.new(trust_level_4).can_convert_topic?(topic)).to be_falsey
    end

    it 'returns false for category definition topics' do
      c = Fabricate(:category)
      topic = Topic.find_by(id: c.topic_id)
      expect(Guardian.new(admin).can_convert_topic?(topic)).to be_falsey
    end

    it 'returns true when a moderator' do
      expect(Guardian.new(moderator).can_convert_topic?(topic)).to be_truthy
    end

    it 'returns true when an admin' do
      expect(Guardian.new(admin).can_convert_topic?(topic)).to be_truthy
    end

    it 'returns false when personal messages are disabled' do
      SiteSetting.enable_personal_messages = false
      expect(Guardian.new(admin).can_convert_topic?(topic)).to be_falsey
    end
  end

  describe 'can_edit?' do

    it 'returns false with a nil object' do
      expect(Guardian.new(user).can_edit?(nil)).to be_falsey
    end

    describe 'a Post' do

      it 'returns false for silenced users' do
        post.user.silenced_till = 1.day.from_now
        expect(Guardian.new(post.user).can_edit?(post)).to be_falsey
      end

      it 'returns false when not logged in' do
        expect(Guardian.new.can_edit?(post)).to be_falsey
      end

      it 'returns false when not logged in also for wiki post' do
        post.wiki = true
        expect(Guardian.new.can_edit?(post)).to be_falsey
      end

      it 'returns true if you want to edit your own post' do
        expect(Guardian.new(post.user).can_edit?(post)).to be_truthy
      end

      it 'returns false if you try to edit a locked post' do
        post.locked_by_id = moderator.id
        expect(Guardian.new(post.user).can_edit?(post)).to be_falsey
      end

      it "returns false if the post is hidden due to flagging and it's too soon" do
        post.hidden = true
        post.hidden_at = Time.now
        expect(Guardian.new(post.user).can_edit?(post)).to be_falsey
      end

      it "returns true if the post is hidden due to flagging and it been enough time" do
        post.hidden = true
        post.hidden_at = (SiteSetting.cooldown_minutes_after_hiding_posts + 1).minutes.ago
        expect(Guardian.new(post.user).can_edit?(post)).to be_truthy
      end

      it "returns true if the post is hidden, it's been enough time and the edit window has expired" do
        post.hidden = true
        post.hidden_at = (SiteSetting.cooldown_minutes_after_hiding_posts + 1).minutes.ago
        post.created_at = (SiteSetting.post_edit_time_limit + 1).minutes.ago
        expect(Guardian.new(post.user).can_edit?(post)).to be_truthy
      end

      it "returns true if the post is hidden due to flagging and it's got a nil `hidden_at`" do
        post.hidden = true
        post.hidden_at = nil
        expect(Guardian.new(post.user).can_edit?(post)).to be_truthy
      end

      it 'returns false if you are trying to edit a post you soft deleted' do
        post.user_deleted = true
        expect(Guardian.new(post.user).can_edit?(post)).to be_falsey
      end

      it 'returns false if another regular user tries to edit a soft deleted wiki post' do
        post.wiki = true
        post.user_deleted = true
        expect(Guardian.new(coding_horror).can_edit?(post)).to be_falsey
      end

      it 'returns false if you are trying to edit a deleted post' do
        post.deleted_at = 1.day.ago
        expect(Guardian.new(post.user).can_edit?(post)).to be_falsey
      end

      it 'returns false if another regular user tries to edit a deleted wiki post' do
        post.wiki = true
        post.deleted_at = 1.day.ago
        expect(Guardian.new(coding_horror).can_edit?(post)).to be_falsey
      end

      it 'returns false if another regular user tries to edit your post' do
        expect(Guardian.new(coding_horror).can_edit?(post)).to be_falsey
      end

      it 'returns true if another regular user tries to edit wiki post' do
        post.wiki = true
        expect(Guardian.new(coding_horror).can_edit?(post)).to be_truthy
      end

      it "returns false if a wiki but the user can't create a post" do
        c = Fabricate(:category)
        c.set_permissions(everyone: :readonly)
        c.save

        topic = Fabricate(:topic, category: c)
        post = Fabricate(:post, topic: topic)
        post.wiki = true

        user = Fabricate(:user)
        expect(Guardian.new(user).can_edit?(post)).to eq(false)
      end

      it 'returns true as a moderator' do
        expect(Guardian.new(moderator).can_edit?(post)).to be_truthy
      end

      it 'returns true as a moderator, even if locked' do
        post.locked_by_id = admin.id
        expect(Guardian.new(moderator).can_edit?(post)).to be_truthy
      end

      it 'returns true as an admin' do
        expect(Guardian.new(admin).can_edit?(post)).to be_truthy
      end

      it 'returns true as a trust level 4 user' do
        expect(Guardian.new(trust_level_4).can_edit?(post)).to be_truthy
      end

      it 'returns false as a TL4 user if trusted_users_can_edit_others is true' do
        SiteSetting.trusted_users_can_edit_others = false
        expect(Guardian.new(trust_level_4).can_edit?(post)).to eq(false)
      end

      it 'returns false when trying to edit a post with no trust' do
        SiteSetting.min_trust_to_edit_post = 2
        post.user.trust_level = 1

        expect(Guardian.new(post.user).can_edit?(post)).to be_falsey
      end

      it 'returns true when trying to edit a post with trust' do
        SiteSetting.min_trust_to_edit_post = 1
        post.user.trust_level = 1

        expect(Guardian.new(post.user).can_edit?(post)).to be_truthy
      end

      it 'returns false when another user has too low trust level to edit wiki post' do
        SiteSetting.min_trust_to_edit_wiki_post = 2
        post.wiki = true
        coding_horror.trust_level = 1

        expect(Guardian.new(coding_horror).can_edit?(post)).to be_falsey
      end

      it 'returns true when another user has adequate trust level to edit wiki post' do
        SiteSetting.min_trust_to_edit_wiki_post = 2
        post.wiki = true
        coding_horror.trust_level = 2

        expect(Guardian.new(coding_horror).can_edit?(post)).to be_truthy
      end

      it 'returns true for post author even when he has too low trust level to edit wiki post' do
        SiteSetting.min_trust_to_edit_wiki_post = 2
        post.wiki = true
        post.user.trust_level = 1

        expect(Guardian.new(post.user).can_edit?(post)).to be_truthy
      end

      context 'post is older than post_edit_time_limit' do
        let(:old_post) { build(:post, topic: topic, user: topic.user, created_at: 6.minutes.ago) }

        before do
          SiteSetting.post_edit_time_limit = 5
        end

        it 'returns false to the author of the post' do
          expect(Guardian.new(old_post.user).can_edit?(old_post)).to be_falsey
        end

        it 'returns true as a moderator' do
          expect(Guardian.new(moderator).can_edit?(old_post)).to eq(true)
        end

        it 'returns true as an admin' do
          expect(Guardian.new(admin).can_edit?(old_post)).to eq(true)
        end

        it 'returns false for another regular user trying to edit your post' do
          expect(Guardian.new(coding_horror).can_edit?(old_post)).to be_falsey
        end

        it 'returns true for another regular user trying to edit a wiki post' do
          old_post.wiki = true
          expect(Guardian.new(coding_horror).can_edit?(old_post)).to be_truthy
        end
      end

      context "first post of a static page doc" do
        let!(:tos_topic) { Fabricate(:topic, user: Discourse.system_user) }
        let!(:tos_first_post) { build(:post, topic: tos_topic, user: tos_topic.user) }
        before { SiteSetting.tos_topic_id = tos_topic.id }

        it "restricts static doc posts" do
          expect(Guardian.new(build(:user)).can_edit?(tos_first_post)).to be_falsey
          expect(Guardian.new(moderator).can_edit?(tos_first_post)).to be_falsey
          expect(Guardian.new(admin).can_edit?(tos_first_post)).to be_truthy
        end
      end
    end

    describe 'a Topic' do

      it 'returns false when not logged in' do
        expect(Guardian.new.can_edit?(topic)).to be_falsey
      end

      it 'returns true for editing your own post' do
        expect(Guardian.new(topic.user).can_edit?(topic)).to eq(true)
      end

      it 'returns false as a regular user' do
        expect(Guardian.new(coding_horror).can_edit?(topic)).to be_falsey
      end

      context 'not archived' do
        it 'returns true as a moderator' do
          expect(Guardian.new(moderator).can_edit?(topic)).to eq(true)
        end

        it 'returns true as an admin' do
          expect(Guardian.new(admin).can_edit?(topic)).to eq(true)
        end

        it 'returns true at trust level 3' do
          expect(Guardian.new(trust_level_3).can_edit?(topic)).to eq(true)
        end

        it 'is false at TL3, if `trusted_users_can_edit_others` is false' do
          SiteSetting.trusted_users_can_edit_others = false
          expect(Guardian.new(trust_level_3).can_edit?(topic)).to eq(false)
        end

        it "returns false when the category is read only" do
          topic.category.set_permissions(everyone: :readonly)
          topic.category.save

          expect(Guardian.new(trust_level_3).can_edit?(topic)).to eq(false)

          expect(Guardian.new(admin).can_edit?(topic)).to eq(true)

          expect(Guardian.new(moderator).can_edit?(post)).to eq(false)
          expect(Guardian.new(moderator).can_edit?(topic)).to eq(false)
        end

        it "returns false for trust level 3 if category is secured" do
          topic.category.set_permissions(everyone: :create_post, staff: :full)
          topic.category.save

          expect(Guardian.new(trust_level_3).can_edit?(topic)).to eq(false)
          expect(Guardian.new(admin).can_edit?(topic)).to eq(true)
          expect(Guardian.new(moderator).can_edit?(topic)).to eq(true)
        end
      end

      context 'private message' do
        it 'returns false at trust level 3' do
          topic.archetype = 'private_message'
          expect(Guardian.new(trust_level_3).can_edit?(topic)).to eq(false)
        end

        it 'returns false at trust level 4' do
          topic.archetype = 'private_message'
          expect(Guardian.new(trust_level_4).can_edit?(topic)).to eq(false)
        end
      end

      context 'archived' do
        let(:archived_topic) { build(:topic, user: user, archived: true) }

        it 'returns true as a moderator' do
          expect(Guardian.new(moderator).can_edit?(archived_topic)).to be_truthy
        end

        it 'returns true as an admin' do
          expect(Guardian.new(admin).can_edit?(archived_topic)).to be_truthy
        end

        it 'returns true at trust level 4' do
          expect(Guardian.new(trust_level_4).can_edit?(archived_topic)).to be_truthy
        end

        it 'is false at TL4, if `trusted_users_can_edit_others` is false' do
          SiteSetting.trusted_users_can_edit_others = false
          expect(Guardian.new(trust_level_4).can_edit?(archived_topic)).to eq(false)
        end

        it 'returns false at trust level 3' do
          expect(Guardian.new(trust_level_3).can_edit?(archived_topic)).to be_falsey
        end

        it 'returns false as a topic creator' do
          expect(Guardian.new(user).can_edit?(archived_topic)).to be_falsey
        end
      end

      context 'very old' do
        let(:old_topic) { build(:topic, user: user, created_at: 6.minutes.ago) }

        before { SiteSetting.post_edit_time_limit = 5 }

        it 'returns true as a moderator' do
          expect(Guardian.new(moderator).can_edit?(old_topic)).to be_truthy
        end

        it 'returns true as an admin' do
          expect(Guardian.new(admin).can_edit?(old_topic)).to be_truthy
        end

        it 'returns true at trust level 3' do
          expect(Guardian.new(trust_level_3).can_edit?(old_topic)).to be_truthy
        end

        it 'returns false as a topic creator' do
          expect(Guardian.new(user).can_edit?(old_topic)).to be_falsey
        end
      end
    end

    describe 'a Category' do

      let(:category) { Fabricate(:category) }

      it 'returns false when not logged in' do
        expect(Guardian.new.can_edit?(category)).to be_falsey
      end

      it 'returns false as a regular user' do
        expect(Guardian.new(category.user).can_edit?(category)).to be_falsey
      end

      it 'returns false as a moderator' do
        expect(Guardian.new(moderator).can_edit?(category)).to be_falsey
      end

      it 'returns true as an admin' do
        expect(Guardian.new(admin).can_edit?(category)).to be_truthy
      end
    end

    describe 'a User' do

      it 'returns false when not logged in' do
        expect(Guardian.new.can_edit?(user)).to be_falsey
      end

      it 'returns false as a different user' do
        expect(Guardian.new(coding_horror).can_edit?(user)).to be_falsey
      end

      it 'returns true when trying to edit yourself' do
        expect(Guardian.new(user).can_edit?(user)).to be_truthy
      end

      it 'returns true as a moderator' do
        expect(Guardian.new(moderator).can_edit?(user)).to be_truthy
      end

      it 'returns true as an admin' do
        expect(Guardian.new(admin).can_edit?(user)).to be_truthy
      end
    end

  end

  context 'can_moderate?' do

    it 'returns false with a nil object' do
      expect(Guardian.new(user).can_moderate?(nil)).to be_falsey
    end

    context 'when user is silenced' do
      it 'returns false' do
        user.update_column(:silenced_till, 1.year.from_now)
        expect(Guardian.new(user).can_moderate?(post)).to be(false)
        expect(Guardian.new(user).can_moderate?(topic)).to be(false)
      end
    end

    context 'a Topic' do

      it 'returns false when not logged in' do
        expect(Guardian.new.can_moderate?(topic)).to be_falsey
      end

      it 'returns false when not a moderator' do
        expect(Guardian.new(user).can_moderate?(topic)).to be_falsey
      end

      it 'returns true when a moderator' do
        expect(Guardian.new(moderator).can_moderate?(topic)).to be_truthy
      end

      it 'returns true when an admin' do
        expect(Guardian.new(admin).can_moderate?(topic)).to be_truthy
      end

      it 'returns true when trust level 4' do
        expect(Guardian.new(trust_level_4).can_moderate?(topic)).to be_truthy
      end

    end

  end

  context 'can_see_flags?' do

    it "returns false when there is no post" do
      expect(Guardian.new(moderator).can_see_flags?(nil)).to be_falsey
    end

    it "returns false when there is no user" do
      expect(Guardian.new(nil).can_see_flags?(post)).to be_falsey
    end

    it "allow regular users to see flags" do
      expect(Guardian.new(user).can_see_flags?(post)).to be_falsey
    end

    it "allows moderators to see flags" do
      expect(Guardian.new(moderator).can_see_flags?(post)).to be_truthy
    end

    it "allows moderators to see flags" do
      expect(Guardian.new(admin).can_see_flags?(post)).to be_truthy
    end
  end

  context 'can_move_posts?' do

    it 'returns false with a nil object' do
      expect(Guardian.new(user).can_move_posts?(nil)).to be_falsey
    end

    context 'a Topic' do

      it 'returns false when not logged in' do
        expect(Guardian.new.can_move_posts?(topic)).to be_falsey
      end

      it 'returns false when not a moderator' do
        expect(Guardian.new(user).can_move_posts?(topic)).to be_falsey
      end

      it 'returns true when a moderator' do
        expect(Guardian.new(moderator).can_move_posts?(topic)).to be_truthy
      end

      it 'returns true when an admin' do
        expect(Guardian.new(admin).can_move_posts?(topic)).to be_truthy
      end

    end

  end

  context 'can_delete?' do

    it 'returns false with a nil object' do
      expect(Guardian.new(user).can_delete?(nil)).to be_falsey
    end

    context 'a Topic' do
      before do
        # pretend we have a real topic
        topic.id = 9999999
      end

      it 'returns false when not logged in' do
        expect(Guardian.new.can_delete?(topic)).to be_falsey
      end

      it 'returns false when not a moderator' do
        expect(Guardian.new(user).can_delete?(topic)).to be_falsey
      end

      it 'returns true when a moderator' do
        expect(Guardian.new(moderator).can_delete?(topic)).to be_truthy
      end

      it 'returns true when an admin' do
        expect(Guardian.new(admin).can_delete?(topic)).to be_truthy
      end

      it 'returns false for static doc topics' do
        tos_topic = Fabricate(:topic, user: Discourse.system_user)
        SiteSetting.tos_topic_id = tos_topic.id
        expect(Guardian.new(admin).can_delete?(tos_topic)).to be_falsey
      end
    end

    context 'a Post' do

      before do
        post.post_number = 2
      end

      it 'returns false when not logged in' do
        expect(Guardian.new.can_delete?(post)).to be_falsey
      end

      it "returns false when trying to delete your own post that has already been deleted" do
        post = Fabricate(:post)
        PostDestroyer.new(user, post).destroy
        post.reload
        expect(Guardian.new(user).can_delete?(post)).to be_falsey
      end

      it 'returns true when trying to delete your own post' do
        expect(Guardian.new(user).can_delete?(post)).to be_truthy
      end

      it "returns false when trying to delete another user's own post" do
        expect(Guardian.new(Fabricate(:user)).can_delete?(post)).to be_falsey
      end

      it "returns false when it's the OP, even as a moderator" do
        post.update_attribute :post_number, 1
        expect(Guardian.new(moderator).can_delete?(post)).to be_falsey
      end

      it 'returns true when a moderator' do
        expect(Guardian.new(moderator).can_delete?(post)).to be_truthy
      end

      it 'returns true when an admin' do
        expect(Guardian.new(admin).can_delete?(post)).to be_truthy
      end

      it 'returns false when post is first in a static doc topic' do
        tos_topic = Fabricate(:topic, user: Discourse.system_user)
        SiteSetting.tos_topic_id = tos_topic.id
        post.update_attribute :post_number, 1
        post.update_attribute :topic_id, tos_topic.id
        expect(Guardian.new(admin).can_delete?(post)).to be_falsey
      end

      context 'the topic is archived' do
        before do
          post.topic.archived = true
        end

        it "allows a staff member to delete it" do
          expect(Guardian.new(moderator).can_delete?(post)).to be_truthy
        end

        it "doesn't allow a regular user to delete it" do
          expect(Guardian.new(post.user).can_delete?(post)).to be_falsey
        end

      end

    end

    context 'a Category' do

      let(:category) { build(:category, user: moderator) }

      it 'returns false when not logged in' do
        expect(Guardian.new.can_delete?(category)).to be_falsey
      end

      it 'returns false when a regular user' do
        expect(Guardian.new(user).can_delete?(category)).to be_falsey
      end

      it 'returns false when a moderator' do
        expect(Guardian.new(moderator).can_delete?(category)).to be_falsey
      end

      it 'returns true when an admin' do
        expect(Guardian.new(admin).can_delete?(category)).to be_truthy
      end

      it "can't be deleted if it has a forum topic" do
        category.topic_count = 10
        expect(Guardian.new(moderator).can_delete?(category)).to be_falsey
      end

      it "can't be deleted if it is the Uncategorized Category" do
        uncategorized_cat_id = SiteSetting.uncategorized_category_id
        uncategorized_category = Category.find(uncategorized_cat_id)
        expect(Guardian.new(admin).can_delete?(uncategorized_category)).to be_falsey
      end

      it "can't be deleted if it has children" do
        category.expects(:has_children?).returns(true)
        expect(Guardian.new(admin).can_delete?(category)).to be_falsey
      end

    end

    context 'can_suspend?' do
      it 'returns false when a user tries to suspend another user' do
        expect(Guardian.new(user).can_suspend?(coding_horror)).to be_falsey
      end

      it 'returns true when an admin tries to suspend another user' do
        expect(Guardian.new(admin).can_suspend?(coding_horror)).to be_truthy
      end

      it 'returns true when a moderator tries to suspend another user' do
        expect(Guardian.new(moderator).can_suspend?(coding_horror)).to be_truthy
      end

      it 'returns false when staff tries to suspend staff' do
        expect(Guardian.new(admin).can_suspend?(moderator)).to be_falsey
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
        expect(Guardian.new.can_delete?(post_action)).to be_falsey
      end

      it 'returns false when not the user who created it' do
        expect(Guardian.new(coding_horror).can_delete?(post_action)).to be_falsey
      end

      it "returns false if the window has expired" do
        post_action.created_at = 20.minutes.ago
        SiteSetting.expects(:post_undo_action_window_mins).returns(10)
        expect(Guardian.new(user).can_delete?(post_action)).to be_falsey
      end

      it "returns true if it's yours" do
        expect(Guardian.new(user).can_delete?(post_action)).to be_truthy
      end

    end

  end

  context 'can_approve?' do

    it "wont allow a non-logged in user to approve" do
      expect(Guardian.new.can_approve?(user)).to be_falsey
    end

    it "wont allow a non-admin to approve a user" do
      expect(Guardian.new(coding_horror).can_approve?(user)).to be_falsey
    end

    it "returns false when the user is already approved" do
      user.approved = true
      expect(Guardian.new(admin).can_approve?(user)).to be_falsey
    end

    it "returns false when the user is not active" do
      user.active = false
      expect(Guardian.new(admin).can_approve?(user)).to be_falsey
    end

    it "allows an admin to approve a user" do
      expect(Guardian.new(admin).can_approve?(user)).to be_truthy
    end

    it "allows a moderator to approve a user" do
      expect(Guardian.new(moderator).can_approve?(user)).to be_truthy
    end

  end

  context 'can_grant_admin?' do
    it "wont allow a non logged in user to grant an admin's access" do
      expect(Guardian.new.can_grant_admin?(another_admin)).to be_falsey
    end

    it "wont allow a regular user to revoke an admin's access" do
      expect(Guardian.new(user).can_grant_admin?(another_admin)).to be_falsey
    end

    it 'wont allow an admin to grant their own access' do
      expect(Guardian.new(admin).can_grant_admin?(admin)).to be_falsey
    end

    it "allows an admin to grant a regular user access" do
      admin.id = 1
      user.id = 2
      expect(Guardian.new(admin).can_grant_admin?(user)).to be_truthy
    end

    it 'should not allow an admin to grant admin access to a non real user' do
      begin
        Discourse.system_user.update!(admin: false)
        expect(Guardian.new(admin).can_grant_admin?(Discourse.system_user)).to be(false)
      ensure
        Discourse.system_user.update!(admin: true)
      end
    end
  end

  context 'can_revoke_admin?' do
    it "wont allow a non logged in user to revoke an admin's access" do
      expect(Guardian.new.can_revoke_admin?(another_admin)).to be_falsey
    end

    it "wont allow a regular user to revoke an admin's access" do
      expect(Guardian.new(user).can_revoke_admin?(another_admin)).to be_falsey
    end

    it 'wont allow an admin to revoke their own access' do
      expect(Guardian.new(admin).can_revoke_admin?(admin)).to be_falsey
    end

    it "allows an admin to revoke another admin's access" do
      admin.id = 1
      another_admin.id = 2

      expect(Guardian.new(admin).can_revoke_admin?(another_admin)).to be_truthy
    end

    it "should not allow an admin to revoke a no real user's admin access" do
      expect(Guardian.new(admin).can_revoke_admin?(Discourse.system_user)).to be(false)
    end
  end

  context 'can_grant_moderation?' do

    it "wont allow a non logged in user to grant an moderator's access" do
      expect(Guardian.new.can_grant_moderation?(user)).to be_falsey
    end

    it "wont allow a regular user to revoke an moderator's access" do
      expect(Guardian.new(user).can_grant_moderation?(moderator)).to be_falsey
    end

    it 'will allow an admin to grant their own moderator access' do
      expect(Guardian.new(admin).can_grant_moderation?(admin)).to be_truthy
    end

    it 'wont allow an admin to grant it to an already moderator' do
      expect(Guardian.new(admin).can_grant_moderation?(moderator)).to be_falsey
    end

    it "allows an admin to grant a regular user access" do
      expect(Guardian.new(admin).can_grant_moderation?(user)).to be_truthy
    end

    it "should not allow an admin to grant moderation to a non real user" do
      begin
        Discourse.system_user.update!(moderator: false)
        expect(Guardian.new(admin).can_grant_moderation?(Discourse.system_user)).to be(false)
      ensure
        Discourse.system_user.update!(moderator: true)
      end
    end
  end

  context 'can_revoke_moderation?' do
    it "wont allow a non logged in user to revoke an moderator's access" do
      expect(Guardian.new.can_revoke_moderation?(moderator)).to be_falsey
    end

    it "wont allow a regular user to revoke an moderator's access" do
      expect(Guardian.new(user).can_revoke_moderation?(moderator)).to be_falsey
    end

    it 'wont allow a moderator to revoke their own moderator' do
      expect(Guardian.new(moderator).can_revoke_moderation?(moderator)).to be_falsey
    end

    it "allows an admin to revoke a moderator's access" do
      expect(Guardian.new(admin).can_revoke_moderation?(moderator)).to be_truthy
    end

    it "allows an admin to revoke a moderator's access from self" do
      admin.moderator = true
      expect(Guardian.new(admin).can_revoke_moderation?(admin)).to be_truthy
    end

    it "does not allow revoke from non moderators" do
      expect(Guardian.new(admin).can_revoke_moderation?(admin)).to be_falsey
    end

    it "should not allow an admin to revoke moderation from a non real user" do
      expect(Guardian.new(admin).can_revoke_moderation?(Discourse.system_user)).to be(false)
    end
  end

  context "can_see_invite_details?" do

    it 'is false without a logged in user' do
      expect(Guardian.new(nil).can_see_invite_details?(user)).to be_falsey
    end

    it 'is false without a user to look at' do
      expect(Guardian.new(user).can_see_invite_details?(nil)).to be_falsey
    end

    it 'is true when looking at your own invites' do
      expect(Guardian.new(user).can_see_invite_details?(user)).to be_truthy
    end
  end

  context "can_access_forum?" do

    let(:unapproved_user) { Fabricate.build(:user) }

    context "when must_approve_users is false" do
      before do
        SiteSetting.must_approve_users = false
      end

      it "returns true for a nil user" do
        expect(Guardian.new(nil).can_access_forum?).to be_truthy
      end

      it "returns true for an unapproved user" do
        expect(Guardian.new(unapproved_user).can_access_forum?).to be_truthy
      end
    end

    context 'when must_approve_users is true' do
      before do
        SiteSetting.must_approve_users = true
      end

      it "returns false for a nil user" do
        expect(Guardian.new(nil).can_access_forum?).to be_falsey
      end

      it "returns false for an unapproved user" do
        expect(Guardian.new(unapproved_user).can_access_forum?).to be_falsey
      end

      it "returns true for an admin user" do
        unapproved_user.admin = true
        expect(Guardian.new(unapproved_user).can_access_forum?).to be_truthy
      end

      it "returns true for an approved user" do
        unapproved_user.approved = true
        expect(Guardian.new(unapproved_user).can_access_forum?).to be_truthy
      end

    end

  end

  describe "can_delete_user?" do
    it "is false without a logged in user" do
      expect(Guardian.new(nil).can_delete_user?(user)).to be_falsey
    end

    it "is false without a user to look at" do
      expect(Guardian.new(admin).can_delete_user?(nil)).to be_falsey
    end

    it "is false for regular users" do
      expect(Guardian.new(user).can_delete_user?(coding_horror)).to be_falsey
    end

    context "delete myself" do
      let(:myself) { Fabricate(:user, created_at: 6.months.ago) }
      subject      { Guardian.new(myself).can_delete_user?(myself) }

      it "is true to delete myself and I have never made a post" do
        expect(subject).to be_truthy
      end

      it "is true to delete myself and I have only made 1 post" do
        myself.stubs(:post_count).returns(1)
        expect(subject).to be_truthy
      end

      it "is false to delete myself and I have made 2 posts" do
        myself.stubs(:post_count).returns(2)
        expect(subject).to be_falsey
      end
    end

    shared_examples "can_delete_user examples" do
      it "is true if user is not an admin and has never posted" do
        expect(Guardian.new(actor).can_delete_user?(Fabricate.build(:user, created_at: 100.days.ago))).to be_truthy
      end

      it "is true if user is not an admin and first post is not too old" do
        user = Fabricate.build(:user, created_at: 100.days.ago)
        user.stubs(:post_count).returns(10)
        user.stubs(:first_post_created_at).returns(9.days.ago)
        SiteSetting.delete_user_max_post_age = 10
        expect(Guardian.new(actor).can_delete_user?(user)).to be_truthy
      end

      it "is false if user is an admin" do
        expect(Guardian.new(actor).can_delete_user?(another_admin)).to be_falsey
      end

      it "is false if user's first post is too old" do
        user = Fabricate.build(:user, created_at: 100.days.ago)
        user.stubs(:post_count).returns(10)
        user.stubs(:first_post_created_at).returns(11.days.ago)
        SiteSetting.delete_user_max_post_age = 10
        expect(Guardian.new(actor).can_delete_user?(user)).to be_falsey
      end
    end

    shared_examples "can_delete_user staff examples" do
      it "is true if posts are less than or equal to 5" do
        user = Fabricate.build(:user, created_at: 100.days.ago)
        user.stubs(:post_count).returns(4)
        user.stubs(:first_post_created_at).returns(11.days.ago)
        SiteSetting.delete_user_max_post_age = 10
        expect(Guardian.new(actor).can_delete_user?(user)).to be_truthy
      end
    end

    context "for moderators" do
      let(:actor) { moderator }
      include_examples "can_delete_user examples"
      include_examples "can_delete_user staff examples"
    end

    context "for admins" do
      let(:actor) { admin }
      include_examples "can_delete_user examples"
      include_examples "can_delete_user staff examples"
    end
  end

  describe "can_delete_all_posts?" do
    it "is false without a logged in user" do
      expect(Guardian.new(nil).can_delete_all_posts?(user)).to be_falsey
    end

    it "is false without a user to look at" do
      expect(Guardian.new(admin).can_delete_all_posts?(nil)).to be_falsey
    end

    it "is false for regular users" do
      expect(Guardian.new(user).can_delete_all_posts?(coding_horror)).to be_falsey
    end

    shared_examples "can_delete_all_posts examples" do
      it "is true if user has no posts" do
        SiteSetting.delete_user_max_post_age = 10
        expect(Guardian.new(actor).can_delete_all_posts?(Fabricate(:user, created_at: 100.days.ago))).to be_truthy
      end

      it "is true if user's first post is newer than delete_user_max_post_age days old" do
        user = Fabricate(:user, created_at: 100.days.ago)
        user.stubs(:first_post_created_at).returns(9.days.ago)
        SiteSetting.delete_user_max_post_age = 10
        expect(Guardian.new(actor).can_delete_all_posts?(user)).to be_truthy
      end

      it "is false if user's first post is older than delete_user_max_post_age days old" do
        user = Fabricate(:user, created_at: 100.days.ago)
        user.stubs(:first_post_created_at).returns(11.days.ago)
        SiteSetting.delete_user_max_post_age = 10
        expect(Guardian.new(actor).can_delete_all_posts?(user)).to be_falsey
      end

      it "is false if user is an admin" do
        expect(Guardian.new(actor).can_delete_all_posts?(admin)).to be_falsey
      end

      it "is true if number of posts is small" do
        u = Fabricate(:user, created_at: 1.day.ago)
        u.stubs(:post_count).returns(1)
        SiteSetting.delete_all_posts_max = 10
        expect(Guardian.new(actor).can_delete_all_posts?(u)).to be_truthy
      end

      it "is false if number of posts is not small" do
        u = Fabricate(:user, created_at: 1.day.ago)
        u.stubs(:post_count).returns(11)
        SiteSetting.delete_all_posts_max = 10
        expect(Guardian.new(actor).can_delete_all_posts?(u)).to be_falsey
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

  describe "can_anonymize_user?" do
    it "is false without a logged in user" do
      expect(Guardian.new(nil).can_anonymize_user?(user)).to be_falsey
    end

    it "is false without a user to look at" do
      expect(Guardian.new(admin).can_anonymize_user?(nil)).to be_falsey
    end

    it "is false for a regular user" do
      expect(Guardian.new(user).can_anonymize_user?(coding_horror)).to be_falsey
    end

    it "is false for myself" do
      expect(Guardian.new(user).can_anonymize_user?(user)).to be_falsey
    end

    it "is true for admin anonymizing a regular user" do
      expect(Guardian.new(admin).can_anonymize_user?(user)).to eq(true)
    end

    it "is true for moderator anonymizing a regular user" do
      expect(Guardian.new(moderator).can_anonymize_user?(user)).to eq(true)
    end

    it "is false for admin anonymizing an admin" do
      expect(Guardian.new(admin).can_anonymize_user?(Fabricate(:admin))).to be_falsey
    end

    it "is false for admin anonymizing a moderator" do
      expect(Guardian.new(admin).can_anonymize_user?(Fabricate(:moderator))).to be_falsey
    end

    it "is false for moderator anonymizing an admin" do
      expect(Guardian.new(moderator).can_anonymize_user?(admin)).to be_falsey
    end

    it "is false for moderator anonymizing a moderator" do
      expect(Guardian.new(moderator).can_anonymize_user?(Fabricate(:moderator))).to be_falsey
    end
  end

  describe 'can_grant_title?' do
    it 'is false without a logged in user' do
      expect(Guardian.new(nil).can_grant_title?(user)).to be_falsey
    end

    it 'is false for regular users' do
      expect(Guardian.new(user).can_grant_title?(user)).to be_falsey
    end

    it 'is true for moderators' do
      expect(Guardian.new(moderator).can_grant_title?(user)).to be_truthy
    end

    it 'is true for admins' do
      expect(Guardian.new(admin).can_grant_title?(user)).to be_truthy
    end

    it 'is false without a user to look at' do
      expect(Guardian.new(admin).can_grant_title?(nil)).to be_falsey
    end

    context 'with title argument' do
      let(:title_badge) { Fabricate(:badge, name: 'Helper', allow_title: true) }
      let(:no_title_badge) { Fabricate(:badge, name: 'Writer', allow_title: false) }
      let(:group) { Fabricate(:group, title: 'Groupie') }

      it 'returns true if title belongs to a badge that user has' do
        BadgeGranter.grant(title_badge, user)
        expect(Guardian.new(user).can_grant_title?(user, title_badge.name)).to eq(true)
      end

      it "returns false if title belongs to a badge that user doesn't have" do
        expect(Guardian.new(user).can_grant_title?(user, title_badge.name)).to eq(false)
      end

      it "returns false if title belongs to a badge that user has but can't be used as a title" do
        BadgeGranter.grant(no_title_badge, user)
        expect(Guardian.new(user).can_grant_title?(user, no_title_badge.name)).to eq(false)
      end

      it 'returns true if title is from a group the user belongs to' do
        group.add(user)
        expect(Guardian.new(user).can_grant_title?(user, group.title)).to eq(true)
      end

      it "returns false if title is from a group the user doesn't belong to" do
        expect(Guardian.new(user).can_grant_title?(user, group.title)).to eq(false)
      end

      it "returns true if the title is set to an empty string" do
        expect(Guardian.new(user).can_grant_title?(user, '')).to eq(true)
      end
    end
  end

  describe 'can_change_trust_level?' do

    it 'is false without a logged in user' do
      expect(Guardian.new(nil).can_change_trust_level?(user)).to be_falsey
    end

    it 'is false for regular users' do
      expect(Guardian.new(user).can_change_trust_level?(user)).to be_falsey
    end

    it 'is true for moderators' do
      expect(Guardian.new(moderator).can_change_trust_level?(user)).to be_truthy
    end

    it 'is true for admins' do
      expect(Guardian.new(admin).can_change_trust_level?(user)).to be_truthy
    end
  end

  describe "can_edit_username?" do
    it "is false without a logged in user" do
      expect(Guardian.new(nil).can_edit_username?(build(:user, created_at: 1.minute.ago))).to be_falsey
    end

    it "is false for regular users to edit another user's username" do
      expect(Guardian.new(build(:user)).can_edit_username?(build(:user, created_at: 1.minute.ago))).to be_falsey
    end

    shared_examples "staff can always change usernames" do
      it "is true for moderators" do
        expect(Guardian.new(moderator).can_edit_username?(user)).to be_truthy
      end

      it "is true for admins" do
        expect(Guardian.new(admin).can_edit_username?(user)).to be_truthy
      end
    end

    context 'for a new user' do
      let(:target_user) { Fabricate(:user, created_at: 1.minute.ago) }
      include_examples "staff can always change usernames"

      it "is true for the user to change their own username" do
        expect(Guardian.new(target_user).can_edit_username?(target_user)).to be_truthy
      end
    end

    context 'for an old user' do
      before do
        SiteSetting.username_change_period = 3
      end

      let(:target_user) { Fabricate(:user, created_at: 4.days.ago) }

      context 'with no posts' do
        include_examples "staff can always change usernames"
        it "is true for the user to change their own username" do
          expect(Guardian.new(target_user).can_edit_username?(target_user)).to be_truthy
        end
      end

      context 'with posts' do
        before { target_user.stubs(:post_count).returns(1) }
        include_examples "staff can always change usernames"
        it "is false for the user to change their own username" do
          expect(Guardian.new(target_user).can_edit_username?(target_user)).to be_falsey
        end
      end
    end

    context 'when editing is disabled in preferences' do
      before do
        SiteSetting.username_change_period = 0
      end

      include_examples "staff can always change usernames"

      it "is false for the user to change their own username" do
        expect(Guardian.new(user).can_edit_username?(user)).to be_falsey
      end
    end

    context 'when SSO username override is active' do
      before do
        SiteSetting.sso_url = "https://www.example.com/sso"
        SiteSetting.enable_sso = true
        SiteSetting.sso_overrides_username = true
      end

      it "is false for admins" do
        expect(Guardian.new(admin).can_edit_username?(admin)).to be_falsey
      end

      it "is false for moderators" do
        expect(Guardian.new(moderator).can_edit_username?(moderator)).to be_falsey
      end

      it "is false for users" do
        expect(Guardian.new(user).can_edit_username?(user)).to be_falsey
      end
    end
  end

  describe "can_edit_email?" do
    context 'when allowed in settings' do
      before do
        SiteSetting.email_editable = true
      end

      it "is false when not logged in" do
        expect(Guardian.new(nil).can_edit_email?(build(:user, created_at: 1.minute.ago))).to be_falsey
      end

      it "is false for regular users to edit another user's email" do
        expect(Guardian.new(build(:user)).can_edit_email?(build(:user, created_at: 1.minute.ago))).to be_falsey
      end

      it "is true for a regular user to edit their own email" do
        expect(Guardian.new(user).can_edit_email?(user)).to be_truthy
      end

      it "is true for moderators" do
        expect(Guardian.new(moderator).can_edit_email?(user)).to be_truthy
      end

      it "is true for admins" do
        expect(Guardian.new(admin).can_edit_email?(user)).to be_truthy
      end
    end

    context 'when not allowed in settings' do
      before do
        SiteSetting.email_editable = false
      end

      it "is false when not logged in" do
        expect(Guardian.new(nil).can_edit_email?(build(:user, created_at: 1.minute.ago))).to be_falsey
      end

      it "is false for regular users to edit another user's email" do
        expect(Guardian.new(build(:user)).can_edit_email?(build(:user, created_at: 1.minute.ago))).to be_falsey
      end

      it "is false for a regular user to edit their own email" do
        expect(Guardian.new(user).can_edit_email?(user)).to be_falsey
      end

      it "is false for admins" do
        expect(Guardian.new(admin).can_edit_email?(user)).to be_falsey
      end

      it "is false for moderators" do
        expect(Guardian.new(moderator).can_edit_email?(user)).to be_falsey
      end
    end

    context 'when SSO email override is active' do
      before do
        SiteSetting.email_editable = false
        SiteSetting.sso_url = "https://www.example.com/sso"
        SiteSetting.enable_sso = true
        SiteSetting.sso_overrides_email = true
      end

      it "is false for admins" do
        expect(Guardian.new(admin).can_edit_email?(admin)).to be_falsey
      end

      it "is false for moderators" do
        expect(Guardian.new(moderator).can_edit_email?(moderator)).to be_falsey
      end

      it "is false for users" do
        expect(Guardian.new(user).can_edit_email?(user)).to be_falsey
      end
    end
  end

  describe 'can_edit_name?' do
    it 'is false without a logged in user' do
      expect(Guardian.new(nil).can_edit_name?(build(:user, created_at: 1.minute.ago))).to be_falsey
    end

    it "is false for regular users to edit another user's name" do
      expect(Guardian.new(build(:user)).can_edit_name?(build(:user, created_at: 1.minute.ago))).to be_falsey
    end

    context 'for a new user' do
      let(:target_user) { build(:user, created_at: 1.minute.ago) }

      it 'is true for the user to change their own name' do
        expect(Guardian.new(target_user).can_edit_name?(target_user)).to be_truthy
      end

      it 'is true for moderators' do
        expect(Guardian.new(moderator).can_edit_name?(user)).to be_truthy
      end

      it 'is true for admins' do
        expect(Guardian.new(admin).can_edit_name?(user)).to be_truthy
      end
    end

    context 'when name is disabled in preferences' do
      before do
        SiteSetting.enable_names = false
      end

      it 'is false for the user to change their own name' do
        expect(Guardian.new(user).can_edit_name?(user)).to be_falsey
      end

      it 'is false for moderators' do
        expect(Guardian.new(moderator).can_edit_name?(user)).to be_falsey
      end

      it 'is false for admins' do
        expect(Guardian.new(admin).can_edit_name?(user)).to be_falsey
      end
    end

    context 'when name is enabled in preferences' do
      before do
        SiteSetting.enable_names = true
      end

      context 'when SSO is disabled' do
        before do
          SiteSetting.enable_sso = false
          SiteSetting.sso_overrides_name = false
        end

        it 'is true for admins' do
          expect(Guardian.new(admin).can_edit_name?(admin)).to be_truthy
        end

        it 'is true for moderators' do
          expect(Guardian.new(moderator).can_edit_name?(moderator)).to be_truthy
        end

        it 'is true for users' do
          expect(Guardian.new(user).can_edit_name?(user)).to be_truthy
        end
      end

      context 'when SSO is enabled' do
        before do
          SiteSetting.sso_url = "https://www.example.com/sso"
          SiteSetting.enable_sso = true
        end

        context 'when SSO name override is active' do
          before do
            SiteSetting.sso_overrides_name = true
          end

          it 'is false for admins' do
            expect(Guardian.new(admin).can_edit_name?(admin)).to be_falsey
          end

          it 'is false for moderators' do
            expect(Guardian.new(moderator).can_edit_name?(moderator)).to be_falsey
          end

          it 'is false for users' do
            expect(Guardian.new(user).can_edit_name?(user)).to be_falsey
          end
        end

        context 'when SSO name override is not active' do
          before do
            SiteSetting.sso_overrides_name = false
          end

          it 'is true for admins' do
            expect(Guardian.new(admin).can_edit_name?(admin)).to be_truthy
          end

          it 'is true for moderators' do
            expect(Guardian.new(moderator).can_edit_name?(moderator)).to be_truthy
          end

          it 'is true for users' do
            expect(Guardian.new(user).can_edit_name?(user)).to be_truthy
          end
        end
      end
    end
  end

  describe '#can_export_entity?' do
    let(:user_guardian) { Guardian.new(user) }
    let(:moderator_guardian) { Guardian.new(moderator) }
    let(:admin_guardian) { Guardian.new(admin) }

    it 'only allows admins to export user_list' do
      expect(user_guardian.can_export_entity?('user_list')).to be_falsey
      expect(moderator_guardian.can_export_entity?('user_list')).to be_falsey
      expect(admin_guardian.can_export_entity?('user_list')).to be_truthy
    end

    it 'allow moderators to export other admin entities' do
      expect(user_guardian.can_export_entity?('staff_action')).to be_falsey
      expect(moderator_guardian.can_export_entity?('staff_action')).to be_truthy
      expect(admin_guardian.can_export_entity?('staff_action')).to be_truthy
    end
  end

  describe "#allow_themes?" do
    let(:theme) { Fabricate(:theme) }
    let(:theme2) { Fabricate(:theme) }

    it "allows staff to use any themes" do
      expect(Guardian.new(moderator).allow_themes?([theme.id, theme2.id])).to eq(false)
      expect(Guardian.new(admin).allow_themes?([theme.id, theme2.id])).to eq(false)

      expect(Guardian.new(moderator).allow_themes?([theme.id, theme2.id], include_preview: true)).to eq(true)
      expect(Guardian.new(admin).allow_themes?([theme.id, theme2.id], include_preview: true)).to eq(true)
    end

    it "only allows normal users to use user-selectable themes or default theme" do
      user_guardian = Guardian.new(user)

      expect(user_guardian.allow_themes?([theme.id, theme2.id])).to eq(false)
      expect(user_guardian.allow_themes?([theme.id])).to eq(false)
      expect(user_guardian.allow_themes?([theme2.id])).to eq(false)

      theme.set_default!
      expect(user_guardian.allow_themes?([theme.id])).to eq(true)
      expect(user_guardian.allow_themes?([theme2.id])).to eq(false)
      expect(user_guardian.allow_themes?([theme.id, theme2.id])).to eq(false)

      theme2.update!(user_selectable: true)
      expect(user_guardian.allow_themes?([theme2.id])).to eq(true)
      expect(user_guardian.allow_themes?([theme2.id, theme.id])).to eq(false)
    end

    it "allows child themes to be only used with their parent" do
      user_guardian = Guardian.new(user)

      theme.update!(user_selectable: true)
      theme2.update!(user_selectable: true)
      expect(user_guardian.allow_themes?([theme.id, theme2.id])).to eq(false)

      theme2.update!(user_selectable: false, component: true)
      theme.add_child_theme!(theme2)
      expect(user_guardian.allow_themes?([theme.id, theme2.id])).to eq(true)
      expect(user_guardian.allow_themes?([theme2.id])).to eq(false)
    end
  end

  describe 'can_wiki?' do
    let(:post) { build(:post, created_at: 1.minute.ago) }

    it 'returns false for regular user' do
      expect(Guardian.new(coding_horror).can_wiki?(post)).to be_falsey
    end

    it "returns false when user does not satisfy trust level but owns the post" do
      own_post = Fabricate(:post, user: trust_level_2)
      expect(Guardian.new(trust_level_2).can_wiki?(own_post)).to be_falsey
    end

    it "returns false when user satisfies trust level but tries to wiki someone else's post" do
      SiteSetting.min_trust_to_allow_self_wiki = 2
      expect(Guardian.new(trust_level_2).can_wiki?(post)).to be_falsey
    end

    it 'returns true when user satisfies trust level and owns the post' do
      SiteSetting.min_trust_to_allow_self_wiki = 2
      own_post = Fabricate(:post, user: trust_level_2)
      expect(Guardian.new(trust_level_2).can_wiki?(own_post)).to be_truthy
    end

    it 'returns true for admin user' do
      expect(Guardian.new(admin).can_wiki?(post)).to be_truthy
    end

    it 'returns true for trust_level_4 user' do
      expect(Guardian.new(trust_level_4).can_wiki?(post)).to be_truthy
    end

    context 'post is older than post_edit_time_limit' do
      let(:old_post) { build(:post, user: trust_level_2, created_at: 6.minutes.ago) }
      before do
        SiteSetting.min_trust_to_allow_self_wiki = 2
        SiteSetting.post_edit_time_limit = 5
      end

      it 'returns false when user satisfies trust level and owns the post' do
        expect(Guardian.new(trust_level_2).can_wiki?(old_post)).to be_falsey
      end

      it 'returns true for admin user' do
        expect(Guardian.new(admin).can_wiki?(old_post)).to be_truthy
      end

      it 'returns true for trust_level_4 user' do
        expect(Guardian.new(trust_level_4).can_wiki?(post)).to be_truthy
      end
    end
  end

  describe "Tags" do
    context "tagging disabled" do
      before do
        SiteSetting.tagging_enabled = false
      end

      it "can_create_tag returns false" do
        expect(Guardian.new(admin).can_create_tag?).to be_falsey
      end

      it "can_admin_tags returns false" do
        expect(Guardian.new(admin).can_admin_tags?).to be_falsey
      end

      it "can_admin_tag_groups returns false" do
        expect(Guardian.new(admin).can_admin_tag_groups?).to be_falsey
      end
    end

    context "tagging is enabled" do
      before do
        SiteSetting.tagging_enabled = true
        SiteSetting.min_trust_level_to_tag_topics = 1
      end

      context 'min_trust_to_create_tag is 3' do
        before do
          SiteSetting.min_trust_to_create_tag = 3
        end

        describe "can_create_tag" do
          it "returns false if trust level is too low" do
            expect(Guardian.new(trust_level_2).can_create_tag?).to be_falsey
          end

          it "returns true if trust level is high enough" do
            expect(Guardian.new(trust_level_3).can_create_tag?).to be_truthy
          end

          it "returns true for staff" do
            expect(Guardian.new(admin).can_create_tag?).to be_truthy
            expect(Guardian.new(moderator).can_create_tag?).to be_truthy
          end
        end

        describe "can_tag_topics" do
          it "returns false if trust level is too low" do
            expect(Guardian.new(Fabricate(:user, trust_level: 0)).can_tag_topics?).to be_falsey
          end

          it "returns true if trust level is high enough" do
            expect(Guardian.new(Fabricate(:user, trust_level: 1)).can_tag_topics?).to be_truthy
          end

          it "returns true for staff" do
            expect(Guardian.new(admin).can_tag_topics?).to be_truthy
            expect(Guardian.new(moderator).can_tag_topics?).to be_truthy
          end
        end
      end

      context 'min_trust_to_create_tag is "staff"' do
        before do
          SiteSetting.min_trust_to_create_tag = 'staff'
        end

        it "returns false if not staff" do
          expect(Guardian.new(trust_level_4).can_create_tag?).to eq(false)
        end

        it "returns true if staff" do
          expect(Guardian.new(admin).can_create_tag?).to be_truthy
          expect(Guardian.new(moderator).can_create_tag?).to be_truthy
        end
      end

      context 'min_trust_to_create_tag is "admin"' do
        before do
          SiteSetting.min_trust_to_create_tag = 'admin'
        end

        it "returns false if not admin" do
          expect(Guardian.new(trust_level_4).can_create_tag?).to eq(false)
          expect(Guardian.new(moderator).can_create_tag?).to eq(false)
        end

        it "returns true if admin" do
          expect(Guardian.new(admin).can_create_tag?).to be_truthy
        end
      end
    end
  end

  describe(:can_see_group) do
    it 'Correctly handles owner visibile groups' do
      group = Group.new(name: 'group', visibility_level: Group.visibility_levels[:owners])

      member = Fabricate(:user)
      group.add(member)
      group.save!

      owner = Fabricate(:user)
      group.add_owner(owner)
      group.reload

      expect(Guardian.new(admin).can_see_group?(group)).to eq(true)
      expect(Guardian.new(moderator).can_see_group?(group)).to eq(false)
      expect(Guardian.new(member).can_see_group?(group)).to eq(false)
      expect(Guardian.new.can_see_group?(group)).to eq(false)
      expect(Guardian.new(owner).can_see_group?(group)).to eq(true)
    end

    it 'Correctly handles staff visibile groups' do
      group = Group.new(name: 'group', visibility_level: Group.visibility_levels[:staff])

      member = Fabricate(:user)
      group.add(member)
      group.save!

      owner = Fabricate(:user)
      group.add_owner(owner)
      group.reload

      expect(Guardian.new(member).can_see_group?(group)).to eq(false)
      expect(Guardian.new(admin).can_see_group?(group)).to eq(true)
      expect(Guardian.new(moderator).can_see_group?(group)).to eq(true)
      expect(Guardian.new(owner).can_see_group?(group)).to eq(true)
      expect(Guardian.new.can_see_group?(group)).to eq(false)
    end

    it 'Correctly handles member visibile groups' do
      group = Group.new(name: 'group', visibility_level: Group.visibility_levels[:members])

      member = Fabricate(:user)
      group.add(member)
      group.save!

      owner = Fabricate(:user)
      group.add_owner(owner)
      group.reload

      expect(Guardian.new(moderator).can_see_group?(group)).to eq(false)
      expect(Guardian.new.can_see_group?(group)).to eq(false)
      expect(Guardian.new(admin).can_see_group?(group)).to eq(true)
      expect(Guardian.new(member).can_see_group?(group)).to eq(true)
      expect(Guardian.new(owner).can_see_group?(group)).to eq(true)
    end

    it 'Correctly handles public groups' do
      group = Group.new(name: 'group', visibility_level: Group.visibility_levels[:public])

      expect(Guardian.new.can_see_group?(group)).to eq(true)
    end

  end

  context 'topic featured link category restriction' do
    before { SiteSetting.topic_featured_link_enabled = true }
    let(:guardian) { Guardian.new }
    let(:uncategorized) { Category.find(SiteSetting.uncategorized_category_id) }

    context "uncategorized" do
      let!(:link_category) { Fabricate(:link_category) }

      it "allows featured links if uncategorized allows it" do
        uncategorized.topic_featured_link_allowed = true
        uncategorized.save!
        expect(guardian.can_edit_featured_link?(nil)).to eq(true)
      end

      it "forbids featured links if uncategorized forbids it" do
        uncategorized.topic_featured_link_allowed = false
        uncategorized.save!
        expect(guardian.can_edit_featured_link?(nil)).to eq(false)
      end
    end

    context 'when exist' do
      let!(:category) { Fabricate(:category, topic_featured_link_allowed: false) }
      let!(:link_category) { Fabricate(:link_category) }

      it 'returns true if the category is listed' do
        expect(guardian.can_edit_featured_link?(link_category.id)).to eq(true)
      end

      it 'returns false if the category does not allow it' do
        expect(guardian.can_edit_featured_link?(category.id)).to eq(false)
      end
    end
  end

  context "suspension reasons" do
    let(:user) { Fabricate(:user) }

    it "will be shown by default" do
      expect(Guardian.new.can_see_suspension_reason?(user)).to eq(true)
    end

    context "with hide suspension reason enabled" do
      let(:moderator) { Fabricate(:moderator) }

      before do
        SiteSetting.hide_suspension_reasons = true
      end

      it "will not be shown to anonymous users" do
        expect(Guardian.new.can_see_suspension_reason?(user)).to eq(false)
      end

      it "users can see their own suspensions" do
        expect(Guardian.new(user).can_see_suspension_reason?(user)).to eq(true)
      end

      it "staff can see suspensions" do
        expect(Guardian.new(moderator).can_see_suspension_reason?(user)).to eq(true)
      end
    end
  end

  describe '#can_remove_allowed_users?' do
    context 'staff users' do
      it 'should be true' do
        expect(Guardian.new(moderator).can_remove_allowed_users?(topic))
          .to eq(true)
      end
    end

    context 'normal user' do
      let(:topic) { Fabricate(:topic, user: Fabricate(:user)) }
      let(:another_user) { Fabricate(:user) }

      before do
        topic.allowed_users << user
        topic.allowed_users << another_user
      end

      it 'should be false' do
        expect(Guardian.new(user).can_remove_allowed_users?(topic))
          .to eq(false)
      end

      describe 'target_user is the user' do
        describe 'when user is in a pm with another user' do
          it 'should return true' do
            expect(Guardian.new(user).can_remove_allowed_users?(topic, user))
              .to eq(true)
          end
        end

        describe 'when user is the creator of the topic' do
          it 'should return false' do
            expect(Guardian.new(topic.user).can_remove_allowed_users?(topic, topic.user))
              .to eq(false)
          end
        end

        describe 'when user is the only user in the topic' do
          it 'should return false' do
            topic.remove_allowed_user(Discourse.system_user, another_user.username)

            expect(Guardian.new(user).can_remove_allowed_users?(topic, user))
              .to eq(false)
          end
        end
      end

      describe 'target_user is not the user' do
        it 'should return false' do
          expect(Guardian.new(user).can_remove_allowed_users?(topic, moderator))
            .to eq(false)
        end
      end
    end
  end

  describe '#auth_token' do
    it 'returns the correct auth token' do
      token = UserAuthToken.generate!(user_id: user.id)
      env = Rack::MockRequest.env_for("/", "HTTP_COOKIE" => "_t=#{token.unhashed_auth_token};")

      guardian = Guardian.new(user, Rack::Request.new(env))
      expect(guardian.auth_token).to eq(token.auth_token)
    end
  end
end
