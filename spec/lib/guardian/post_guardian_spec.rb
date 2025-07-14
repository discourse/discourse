# frozen_string_literal: true

RSpec.describe PostGuardian do
  fab!(:groupless_user, :user)
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:anon, :anonymous)
  fab!(:admin)
  fab!(:another_admin) { Fabricate(:admin) }
  fab!(:moderator)
  fab!(:trust_level_0) { Fabricate(:trust_level_0, refresh_auto_groups: true) }
  fab!(:trust_level_4) { Fabricate(:trust_level_4, refresh_auto_groups: true) }
  fab!(:coding_horror) { Fabricate(:coding_horror, refresh_auto_groups: true) }
  fab!(:group)
  fab!(:group_user) { Fabricate(:group_user, group: group, user: user) }
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:post) { Fabricate(:post, topic: topic) }
  fab!(:hidden_post) { Fabricate(:post, topic: topic, hidden: true) }
  fab!(:staff_post) { Fabricate(:post, topic: topic, user: moderator) }

  ###### LINK POSTING ######

  describe "#link_posting_access" do
    it "is none for anonymous users" do
      expect(Guardian.new.link_posting_access).to eq("none")
    end

    it "is full for regular users" do
      expect(Guardian.new(user).link_posting_access).to eq("full")
    end

    it "is full for staff users regardless of TL" do
      SiteSetting.post_links_allowed_groups = Group::AUTO_GROUPS[:trust_level_2]
      admin_user = Fabricate(:admin)
      admin_user.change_trust_level!(TrustLevel[1])
      expect(Guardian.new(admin_user).link_posting_access).to eq("full")
    end

    it "is none for a user of a low trust level" do
      user.change_trust_level!(TrustLevel[0])
      SiteSetting.post_links_allowed_groups = Group::AUTO_GROUPS[:trust_level_1]
      expect(Guardian.new(user).link_posting_access).to eq("none")
    end

    it "is limited for a user of a low trust level with a allowlist" do
      SiteSetting.allowed_link_domains = "example.com"
      user.change_trust_level!(TrustLevel[0])
      SiteSetting.post_links_allowed_groups = Group::AUTO_GROUPS[:trust_level_1]
      expect(Guardian.new(user).link_posting_access).to eq("limited")
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
      user.change_trust_level!(TrustLevel[0])
      SiteSetting.post_links_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
      expect(Guardian.new(user).can_post_link?(host: host)).to eq(true)
      SiteSetting.post_links_allowed_groups = Group::AUTO_GROUPS[:trust_level_1]
      expect(Guardian.new(user).can_post_link?(host: host)).to eq(false)
    end

    describe "allowlisted host" do
      before { SiteSetting.allowed_link_domains = host }

      it "allows a new user to post the link to the host" do
        user.change_trust_level!(TrustLevel[0])
        SiteSetting.post_links_allowed_groups = Group::AUTO_GROUPS[:trust_level_1]
        expect(Guardian.new(user).can_post_link?(host: host)).to eq(true)
        expect(Guardian.new(user).can_post_link?(host: "another-host.com")).to eq(false)
      end
    end
  end

  ###### ACTING ######

  describe "#post_can_act?" do
    fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
    fab!(:post)

    describe "an authenticated user posting anonymously" do
      before { SiteSetting.allow_anonymous_mode = true }

      context "when allow_likes_in_anonymous_mode is enabled" do
        before { SiteSetting.allow_likes_in_anonymous_mode = true }

        it "returns true when liking" do
          expect(Guardian.new(anon).post_can_act?(post, :like)).to be_truthy
        end

        it "cannot perform any other action" do
          expect(Guardian.new(anon).post_can_act?(post, :flag)).to be_falsey
          expect(Guardian.new(anon).post_can_act?(post, :bookmark)).to be_falsey
          expect(Guardian.new(anon).post_can_act?(post, :notify_user)).to be_falsey
        end
      end

      context "when allow_likes_in_anonymous_mode is disabled" do
        before { SiteSetting.allow_likes_in_anonymous_mode = false }

        it "returns false when liking" do
          expect(Guardian.new(anon).post_can_act?(post, :like)).to be_falsey
        end

        it "cannot perform any other action" do
          expect(Guardian.new(anon).post_can_act?(post, :flag)).to be_falsey
          expect(Guardian.new(anon).post_can_act?(post, :bookmark)).to be_falsey
          expect(Guardian.new(anon).post_can_act?(post, :notify_user)).to be_falsey
        end
      end
    end

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
      expect(Guardian.new(admin).post_can_act?(post, :spam)).to be_truthy
      expect(Guardian.new(admin).post_can_act?(post, :notify_user)).to be_truthy
    end

    it "returns false if flag is disabled" do
      expect(Guardian.new(admin).post_can_act?(post, :spam)).to be true
      Flag.where(name: "spam").update!(enabled: false)
      expect(Guardian.new(admin).post_can_act?(post, :spam)).to be false
      Flag.where(name: "spam").update!(enabled: true)
    ensure
      Flag.reset_flag_settings!
    end

    it "return true for illegal if tl0 and allow_all_users_to_flag_illegal_content" do
      SiteSetting.flag_post_allowed_groups = ""
      user.trust_level = TrustLevel[0]
      expect(Guardian.new(user).post_can_act?(post, :illegal)).to be false

      SiteSetting.email_address_to_report_illegal_content = "illegal@example.com"
      SiteSetting.allow_all_users_to_flag_illegal_content = true
      expect(Guardian.new(user).post_can_act?(post, :illegal)).to be true
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
      expect(Guardian.new(user).post_can_act?(staff_post, :spam)).to be_truthy
    end

    describe "when allow_flagging_staff is false" do
      before { SiteSetting.allow_flagging_staff = false }

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
      expect(
        Guardian.new(user).post_can_act?(
          post,
          :like,
          opts: {
            taken_actions: {
              PostActionType.types[:like] => 1,
            },
          },
        ),
      ).to be_falsey
    end

    it "returns false when you already flagged a post" do
      PostActionType.notify_flag_types.each do |type, _id|
        expect(
          Guardian.new(user).post_can_act?(
            post,
            :off_topic,
            opts: {
              taken_actions: {
                PostActionType.types[type] => 1,
              },
            },
          ),
        ).to be_falsey
      end
    end

    it "returns false for notify_user if user is not in any group that can send personal messages" do
      user = Fabricate(:user)
      SiteSetting.personal_message_enabled_groups = Group::AUTO_GROUPS[:staff]
      user.change_trust_level!(1)
      expect(Guardian.new(user).post_can_act?(post, :notify_user)).to be_falsey
    end

    describe "trust levels" do
      before { user.change_trust_level!(TrustLevel[0]) }

      it "returns true for a new user liking something" do
        expect(Guardian.new(user).post_can_act?(post, :like)).to be_truthy
      end

      it "returns false for a new user flagging as spam" do
        expect(Guardian.new(user).post_can_act?(post, :spam)).to be_falsey
      end

      it "returns true for a new user flagging as spam if enabled" do
        SiteSetting.flag_post_allowed_groups = 0
        expect(Guardian.new(user).post_can_act?(post, :spam)).to be_truthy
      end

      it "returns true for a new user flagging a private message as spam" do
        post = Fabricate(:private_message_post, user: admin)
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

  describe "#can_lock_post?" do
    xit do
      # TODO: Add coverage
    end
  end

  describe "#can_recover_post?" do
    it "returns false for a nil user" do
      expect(Guardian.new(nil).can_recover_post?(post)).to be_falsey
    end

    it "returns false for a nil object" do
      expect(Guardian.new(user).can_recover_post?(nil)).to be_falsey
    end

    it "returns false for a regular user" do
      expect(Guardian.new(user).can_recover_post?(post)).to be_falsey
    end

    context "as a moderator" do
      fab!(:topic) { Fabricate(:topic, user: user) }
      fab!(:post) { Fabricate(:post, user: user, topic: topic) }

      describe "when post has been deleted" do
        it "should return the right value" do
          expect(Guardian.new(moderator).can_recover_post?(post)).to be_falsey

          PostDestroyer.new(moderator, post).destroy

          expect(Guardian.new(moderator).can_recover_post?(post.reload)).to be_truthy
        end

        describe "when post's user has been deleted" do
          it "should return the right value" do
            PostDestroyer.new(moderator, post).destroy
            post.user.destroy!

            expect(Guardian.new(moderator).can_recover_post?(post.reload)).to be_truthy
          end
        end
      end
    end
  end

  describe "#can_unhide?" do
    xit do
      # TODO: Add coverage
    end
  end

  describe "#can_skip_bump?" do
    xit do
      # TODO: Add coverage
    end
  end

  ###### CREATING/EDITING ######

  describe "#can_create_post?" do
    it "is false on readonly categories" do
      topic.category = category
      category.set_permissions(everyone: :readonly)
      category.save

      expect(Guardian.new(topic.user).can_create?(Post, topic)).to be_falsey
      expect(Guardian.new(moderator).can_create?(Post, topic)).to be_falsey
    end

    it "is false when not logged in" do
      expect(Guardian.new.can_create?(Post, topic)).to be_falsey
    end

    it "is true for a regular user" do
      expect(Guardian.new(topic.user).can_create?(Post, topic)).to be_truthy
    end

    it "is false when you can't see the topic" do
      Guardian.any_instance.expects(:can_see?).with(topic).returns(false)
      expect(Guardian.new(topic.user).can_create?(Post, topic)).to be_falsey
    end

    context "with closed topic" do
      before { topic.closed = true }

      it "doesn't allow new posts from regular users" do
        expect(Guardian.new(topic.user).can_create?(Post, topic)).to be_falsey
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

    context "with archived topic" do
      before { topic.archived = true }

      context "with regular users" do
        it "doesn't allow new posts from regular users" do
          expect(Guardian.new(coding_horror).can_create?(Post, topic)).to be_falsey
        end

        it "does not allow editing of posts" do
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

    context "with trashed topic" do
      before { topic.trash!(admin) }

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

    context "with system message" do
      fab!(:private_message) do
        Fabricate(
          :topic,
          archetype: Archetype.private_message,
          subtype: "system_message",
          category_id: nil,
        )
      end

      before { user.save! }
      it "allows the user to reply to system messages" do
        expect(Guardian.new(user).can_create_post?(private_message)).to eq(true)
        SiteSetting.enable_system_message_replies = false
        expect(Guardian.new(user).can_create_post?(private_message)).to eq(false)
      end
    end

    context "with private message" do
      fab!(:private_message) do
        Fabricate(:topic, archetype: Archetype.private_message, category_id: nil)
      end

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
  end

  describe "#can_edit_post?" do
    it "returns true for the author" do
      post.update!(user: user)
      expect(Guardian.new(user).can_edit_post?(post)).to eq(true)
    end

    it "returns false for users who are not the author" do
      expect(Guardian.new(user).can_edit_post?(post)).to eq(false)
    end

    it "returns true for admins who are not the author" do
      expect(Guardian.new(admin).can_edit_post?(post)).to eq(true)
    end

    it "returns true for the author if they are anonymous" do
      SiteSetting.allow_anonymous_mode = true
      post.update!(user: anon)
      expect(Guardian.new(anon).can_edit_post?(post)).to eq(true)
    end

    it "returns false if the user is the author, but can no longer see the post" do
      post.update!(user: user)
      guardian = Guardian.new(user)

      guardian.stubs(:can_see_post_topic?).returns(false)

      expect(guardian.can_edit_post?(post)).to eq(false)
    end

    it "returns true even if the topic is closed" do
      topic.update(closed: true)

      post.update!(user: user)
      guardian = Guardian.new(user)

      expect(guardian.can_edit?(post)).to be_truthy
    end
  end

  describe "#can_edit_hidden_post?" do
    xit do
      # TODO: Add coverage
    end
  end

  describe "#can_change_post_owner?" do
    xit do
      # TODO: Add coverage
    end
  end

  describe "#can_change_post_timestamps?" do
    xit do
      # TODO: Add coverage
    end
  end

  describe "#trusted_with_post_edits?" do
    xit do
      # TODO: Add coverage
    end
  end

  describe "#is_in_edit_post_groups?" do
    it "returns true if the user is in edit_all_post_groups" do
      SiteSetting.edit_all_post_groups = group.id.to_s

      expect(Guardian.new(user).is_in_edit_post_groups?).to eq(true)
    end

    it "returns false if the user is not in edit_all_post_groups" do
      SiteSetting.edit_all_post_groups = Group::AUTO_GROUPS[:trust_level_4]

      expect(Guardian.new(Fabricate(:trust_level_3)).is_in_edit_post_groups?).to eq(false)
    end

    it "returns false if the edit_all_post_groups is empty" do
      SiteSetting.edit_all_post_groups = nil

      expect(Guardian.new(user).is_in_edit_post_groups?).to eq(false)
    end
  end

  ###### DELETING ######

  describe "#can_delete_post?" do
    xit do
      # TODO: Add coverage
    end
  end

  describe "#can_delete_post_or_topic?" do
    xit do
      # TODO: Add coverage
    end
  end

  describe "#can_permanently_delete_post?" do
    xit do
      # TODO: Add coverage
    end
  end

  describe "#can_delete_all_posts?" do
    it "is false without a logged in user" do
      expect(Guardian.new(nil).can_delete_all_posts?(user)).to be_falsey
    end

    it "is false without a user to look at" do
      expect(Guardian.new(admin).can_delete_all_posts?(nil)).to be_falsey
    end

    it "is false for regular users" do
      expect(Guardian.new(user).can_delete_all_posts?(coding_horror)).to be_falsey
    end

    context "for moderators" do
      let(:actor) { moderator }

      it "is true if user has no posts" do
        SiteSetting.delete_user_max_post_age = 10
        expect(
          Guardian.new(actor).can_delete_all_posts?(Fabricate(:user, created_at: 100.days.ago)),
        ).to be_truthy
      end

      it "is true if user's first post is newer than delete_user_max_post_age days old" do
        user = Fabricate(:user, created_at: 100.days.ago)
        user.user_stat.update!(first_post_created_at: 9.days.ago)
        SiteSetting.delete_user_max_post_age = 10
        expect(Guardian.new(actor).can_delete_all_posts?(user)).to be_truthy
      end

      it "is false if user's first post is older than delete_user_max_post_age days old" do
        user = Fabricate(:user, created_at: 100.days.ago)
        user.user_stat.update!(first_post_created_at: 11.days.ago)
        SiteSetting.delete_user_max_post_age = 10
        expect(Guardian.new(actor).can_delete_all_posts?(user)).to be_falsey
      end

      it "is false if user is an admin" do
        expect(Guardian.new(actor).can_delete_all_posts?(admin)).to be_falsey
      end

      it "is true if number of posts is small" do
        user = Fabricate(:user, created_at: 1.day.ago)
        user.user_stat.update!(post_count: 1)
        SiteSetting.delete_all_posts_max = 10
        expect(Guardian.new(actor).can_delete_all_posts?(user)).to be_truthy
      end

      it "is false if number of posts is not small" do
        user = Fabricate(:user, created_at: 1.day.ago)
        user.user_stat.update!(post_count: 11)
        SiteSetting.delete_all_posts_max = 10
        expect(Guardian.new(actor).can_delete_all_posts?(user)).to be_falsey
      end
    end

    context "for admins" do
      let(:actor) { admin }

      it "is true if user has no posts" do
        SiteSetting.delete_user_max_post_age = 10
        expect(
          Guardian.new(actor).can_delete_all_posts?(Fabricate(:user, created_at: 100.days.ago)),
        ).to be_truthy
      end

      it "is true if user's first post is newer than delete_user_max_post_age days old" do
        user = Fabricate(:user, created_at: 100.days.ago)
        user.stubs(:first_post_created_at).returns(9.days.ago)
        SiteSetting.delete_user_max_post_age = 10
        expect(Guardian.new(actor).can_delete_all_posts?(user)).to be_truthy
      end

      it "is true if user's first post is older than delete_user_max_post_age days old" do
        user = Fabricate(:user, created_at: 100.days.ago)
        user.stubs(:first_post_created_at).returns(11.days.ago)
        SiteSetting.delete_user_max_post_age = 10
        expect(Guardian.new(actor).can_delete_all_posts?(user)).to be_truthy
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

      it "is true if number of posts is not small" do
        u = Fabricate(:user, created_at: 1.day.ago)
        u.stubs(:post_count).returns(11)
        SiteSetting.delete_all_posts_max = 10
        expect(Guardian.new(actor).can_delete_all_posts?(u)).to be_truthy
      end
    end
  end

  describe "#can_delete_post_action?" do
    before { SiteSetting.allow_anonymous_mode = true }

    context "with allow_likes_in_anonymous_mode enabled" do
      before { SiteSetting.allow_likes_in_anonymous_mode = true }

      describe "an authenticated anonymous user" do
        let(:post_action) do
          user.id = anon.id
          post.id = 1

          a =
            PostAction.new(user: anon, post: post, post_action_type_id: PostActionType.types[:like])
          a.created_at = 1.minute.ago
          a
        end

        let(:non_like_post_action) do
          user.id = anon.id
          post.id = 1

          a =
            PostAction.new(
              user: anon,
              post: post,
              post_action_type_id: PostActionType.types[:reply],
            )
          a.created_at = 1.minute.ago
          a
        end

        let(:other_users_post_action) do
          post.id = 1

          a =
            PostAction.new(user: user, post: post, post_action_type_id: PostActionType.types[:like])
          a.created_at = 1.minute.ago
          a
        end

        it "returns true if the post belongs to the anonymous user" do
          expect(Guardian.new(anon).can_delete_post_action?(post_action)).to be_truthy
        end

        it "returns false if the user is an unauthenticated anonymous user" do
          expect(Guardian.new.can_delete_post_action?(post_action)).to be_falsey
        end

        it "return false if the post belongs to another user" do
          expect(Guardian.new(anon).can_delete_post_action?(other_users_post_action)).to be_falsey
        end

        it "returns false for any other action" do
          expect(Guardian.new(anon).can_delete_post_action?(non_like_post_action)).to be_falsey
        end

        it "returns false if the window has expired" do
          post_action.created_at = 20.minutes.ago
          SiteSetting.post_undo_action_window_mins = 10

          expect(Guardian.new(anon).can_delete?(post_action)).to be_falsey
        end
      end
    end

    context "with allow_likes_in_anonymous_mode disabled" do
      before do
        SiteSetting.allow_likes_in_anonymous_mode = false
        SiteSetting.allow_anonymous_mode = true
      end
      describe "an anonymous user" do
        let(:post_action) do
          user.id = anon.id
          post.id = 1

          a =
            PostAction.new(user: anon, post: post, post_action_type_id: PostActionType.types[:like])
          a.created_at = 1.minute.ago
          a
        end

        let(:non_like_post_action) do
          user.id = anon.id
          post.id = 1

          a =
            PostAction.new(
              user: anon,
              post: post,
              post_action_type_id: PostActionType.types[:reply],
            )
          a.created_at = 1.minute.ago
          a
        end

        it "any action returns false" do
          expect(Guardian.new(anon).can_delete_post_action?(post_action)).to be_falsey
          expect(Guardian.new(anon).can_delete_post_action?(non_like_post_action)).to be_falsey
        end
      end
    end
  end

  ###### VISIBILITY ######

  describe "#can_see_post?" do
    it "correctly handles post visibility" do
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

    it "respects category group moderator settings" do
      group_user = Fabricate(:group_user)
      user_gm = group_user.user
      group = group_user.group
      SiteSetting.enable_category_group_moderation = true

      expect(Guardian.new(user_gm).can_see?(post)).to be_truthy

      post.trash!(another_admin)
      post.reload

      expect(Guardian.new(user_gm).can_see?(post)).to be_falsey

      post.topic.category.update!(topic_id: post.topic.id)
      Fabricate(:category_moderation_group, category: post.topic.category, group:)
      expect(Guardian.new(user_gm).can_see?(post)).to be_truthy
    end

    it "TL4 users can see their deleted posts" do
      user = Fabricate(:user, trust_level: 4)
      user2 = Fabricate(:user, trust_level: 4)
      post = Fabricate(:post, user: user, topic: Fabricate(:post).topic)

      expect(Guardian.new(user).can_see?(post)).to eq(true)
      PostDestroyer.new(user, post).destroy
      expect(Guardian.new(user).can_see?(post)).to eq(true)
      expect(Guardian.new(user2).can_see?(post)).to eq(false)
    end

    it "respects whispers" do
      SiteSetting.whispers_allowed_groups = "#{Group::AUTO_GROUPS[:staff]}|#{group.id}"

      regular_post = post
      whisper_post = Fabricate(:post, post_type: Post.types[:whisper])

      anon_guardian = Guardian.new
      expect(anon_guardian.can_see?(regular_post)).to eq(true)
      expect(anon_guardian.can_see?(whisper_post)).to eq(false)

      regular_user = Fabricate(:user)
      regular_guardian = Guardian.new(regular_user)
      expect(regular_guardian.can_see?(regular_post)).to eq(true)
      expect(regular_guardian.can_see?(whisper_post)).to eq(false)

      # can see your own whispers
      regular_whisper = Fabricate(:post, post_type: Post.types[:whisper], user: regular_user)
      expect(regular_guardian.can_see?(regular_whisper)).to eq(true)

      mod_guardian = Guardian.new(Fabricate(:moderator))
      expect(mod_guardian.can_see?(regular_post)).to eq(true)
      expect(mod_guardian.can_see?(whisper_post)).to eq(true)

      admin_guardian = Guardian.new(Fabricate(:admin))
      expect(admin_guardian.can_see?(regular_post)).to eq(true)
      expect(admin_guardian.can_see?(whisper_post)).to eq(true)

      whisperer_guardian = Guardian.new(Fabricate(:user, groups: [group]))
      expect(whisperer_guardian.can_see?(regular_post)).to eq(true)
      expect(whisperer_guardian.can_see?(whisper_post)).to eq(true)
    end
  end

  describe "#can_see_hidden_post?" do
    context "when the hidden_post_visible_groups contains everyone" do
      before { SiteSetting.hidden_post_visible_groups = "#{Group::AUTO_GROUPS[:everyone]}" }

      it "returns true for everyone" do
        expect(Guardian.new(anon).can_see_hidden_post?(hidden_post)).to eq(true)
        expect(Guardian.new(user).can_see_hidden_post?(hidden_post)).to eq(true)
        expect(Guardian.new(admin).can_see_hidden_post?(hidden_post)).to eq(true)
        expect(Guardian.new(moderator).can_see_hidden_post?(hidden_post)).to eq(true)
      end
    end

    context "when the post is a created by the user" do
      fab!(:hidden_post) { Fabricate(:post, topic: topic, hidden: true, user: user) }

      before { SiteSetting.hidden_post_visible_groups = "" }

      it "returns true for the author" do
        SiteSetting.hidden_post_visible_groups = ""
        expect(Guardian.new(user).can_see_hidden_post?(hidden_post)).to eq(true)
      end
    end

    context "when the post is a created by another user" do
      before { SiteSetting.hidden_post_visible_groups = "14|#{group.id}" }

      it "returns true for staff users" do
        expect(Guardian.new(admin).can_see_hidden_post?(hidden_post)).to eq(true)
        expect(Guardian.new(moderator).can_see_hidden_post?(hidden_post)).to eq(true)
      end

      it "returns false for anonymous users" do
        expect(Guardian.new(anon).can_see_hidden_post?(hidden_post)).to eq(false)
      end

      it "returns true if the user is in hidden_post_visible_groups" do
        expect(Guardian.new(user).can_see_hidden_post?(hidden_post)).to eq(true)
      end

      it "returns false if the user is not in hidden_post_visible_groups" do
        expect(Guardian.new(groupless_user).can_see_hidden_post?(hidden_post)).to eq(false)
      end
    end
  end

  describe "#can_see_deleted_post?" do
    fab!(:post)

    before { post.trash!(user) }

    it "returns false for post that is not deleted" do
      post.recover!
      expect(Guardian.new(admin).can_see_deleted_post?(post)).to be_falsey
    end

    it "returns false for anon" do
      expect(Guardian.new.can_see_deleted_post?(post)).to be_falsey
    end

    it "returns true for admin" do
      expect(Guardian.new(admin).can_see_deleted_post?(post)).to be_truthy
    end

    it "returns true for mods" do
      expect(Guardian.new(moderator).can_see_deleted_post?(post)).to be_truthy
    end

    it "returns false for < TL4 users" do
      user.update!(trust_level: TrustLevel[1])
      expect(Guardian.new(user).can_see_deleted_post?(post)).to be_falsey
    end

    it "returns false if not the person who deleted it" do
      post.update!(deleted_by: trust_level_4)
      expect(Guardian.new(user).can_see_deleted_post?(post)).to be_falsey
    end

    it "returns true for TL4 users' own posts" do
      user.update!(trust_level: TrustLevel[4])
      expect(Guardian.new(user).can_see_deleted_post?(post)).to be_truthy
    end
  end

  describe "#can_see_deleted_posts?" do
    it "returns true if the user is an admin" do
      expect(Guardian.new(admin).can_see_deleted_posts?(post.topic.category)).to be_truthy
    end

    it "returns true if the user is a moderator of category" do
      expect(Guardian.new(moderator).can_see_deleted_posts?(post.topic.category)).to be_truthy
    end

    it "returns true when tl4 can delete posts and topics" do
      expect(Guardian.new(trust_level_4).can_see_deleted_posts?(post)).to be_falsey
      SiteSetting.delete_all_posts_and_topics_allowed_groups = Group::AUTO_GROUPS[:trust_level_4]
      expect(Guardian.new(trust_level_4).can_see_deleted_posts?(post)).to be_truthy
    end
  end

  describe "#can_see_post_actors?" do
    let(:topic) { Fabricate(:topic, user: coding_horror) }

    it "displays visibility correctly" do
      guardian = Guardian.new(user)
      expect(guardian.can_see_post_actors?(nil, PostActionType.types[:like])).to be_falsey
      expect(guardian.can_see_post_actors?(topic, PostActionType.types[:like])).to be_truthy
      expect(guardian.can_see_post_actors?(topic, PostActionType.types[:off_topic])).to be_falsey
      expect(guardian.can_see_post_actors?(topic, PostActionType.types[:spam])).to be_falsey
      expect(guardian.can_see_post_actors?(topic, PostActionType.types[:notify_user])).to be_falsey

      expect(
        Guardian.new(moderator).can_see_post_actors?(topic, PostActionType.types[:notify_user]),
      ).to be_truthy
    end
  end

  describe "#can_view_edit_history?" do
    xit do
      # TODO: Add coverage
    end
  end

  describe "#can_view_raw_email?" do
    xit do
      # TODO: Add coverage
    end
  end

  describe "#can_receive_post_notifications?" do
    it "returns false with a nil object" do
      expect(Guardian.new.can_receive_post_notifications?(nil)).to be_falsey
      expect(Guardian.new(user).can_receive_post_notifications?(nil)).to be_falsey
    end

    it "does not allow anonymous to be notified" do
      expect(Guardian.new.can_receive_post_notifications?(post)).to be_falsey
    end

    it "allows public categories" do
      expect(Guardian.new(trust_level_0).can_receive_post_notifications?(post)).to be_truthy
      expect(Guardian.new(admin).can_receive_post_notifications?(post)).to be_truthy
    end

    it "disallows secure categories with no access" do
      secure_category = Fabricate(:category, read_restricted: true)
      post.topic.update!(category_id: secure_category.id)

      expect(Guardian.new(trust_level_0).can_receive_post_notifications?(post)).to be_falsey
      expect(Guardian.new(admin).can_receive_post_notifications?(post)).to be_truthy

      SiteSetting.suppress_secured_categories_from_admin = true

      expect(Guardian.new(admin).can_receive_post_notifications?(post)).to be_falsey

      secure_category.set_permissions(group => :write)
      secure_category.save!

      group.add(admin)
      group.save!

      expect(Guardian.new(admin).can_receive_post_notifications?(post)).to be_truthy
    end

    it "disallows private messages with no access" do
      post = Fabricate(:private_message_post, user: moderator)

      expect(Guardian.new(trust_level_0).can_receive_post_notifications?(post)).to be_falsey
      expect(Guardian.new(admin).can_receive_post_notifications?(post)).to be_truthy

      SiteSetting.suppress_secured_categories_from_admin = true

      expect(Guardian.new(admin).can_receive_post_notifications?(post)).to be_falsey

      post.topic.allowed_users << admin
      expect(Guardian.new(admin).can_receive_post_notifications?(post)).to be_truthy
    end
  end
end
