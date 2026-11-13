# frozen_string_literal: true

RSpec.describe PostGuardian do
  fab!(:groupless_user, :user)
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:anon, :anonymous)
  fab!(:admin)
  fab!(:another_admin, :admin)
  fab!(:moderator)
  fab!(:trust_level_0) { Fabricate(:trust_level_0, refresh_auto_groups: true) }
  fab!(:trust_level_4) { Fabricate(:trust_level_4, refresh_auto_groups: true) }
  fab!(:coding_horror) { Fabricate(:coding_horror, refresh_auto_groups: true) }
  fab!(:group)
  fab!(:group_user) { Fabricate(:group_user, group: group, user: user) }
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:post) { Fabricate(:post, topic: topic) }
  fab!(:second_post) { Fabricate(:post, topic: topic) }
  fab!(:hidden_post) { Fabricate(:post, topic: topic, hidden: true) }
  fab!(:staff_post) { Fabricate(:post, topic: topic, user: moderator) }

  before do
    Guardian.enable_topic_can_see_consistency_check
    Guardian.enable_post_can_see_consistency_check
  end

  after do
    Guardian.disable_topic_can_see_consistency_check
    Guardian.disable_post_can_see_consistency_check
  end

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

    it "uses deleted topic state when checking flags and archived actions" do
      SiteSetting.enable_category_group_moderation = true
      Fabricate(:category_moderation_group, category: category, group: group)
      group.add(user)
      post.topic.update!(category: category, archived: true)
      post.topic.trash!(admin)
      candidate = Post.find(post.id)
      SiteSetting.flag_post_allowed_groups = Group::AUTO_GROUPS[:admins].to_s
      expect(user.guardian.post_can_act?(candidate, :spam)).to be_falsey
      expect(user.guardian.post_can_act?(candidate, :like)).to be_falsey
      expect(candidate.association(:topic).loaded?).to eq(false)
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
      expect(Guardian.new(user).post_can_act?(post, :like)).to be_falsey
      expect(Guardian.new(user).post_can_act?(post, :bookmark)).to be_truthy
    end

    it "lets silenced users flag illegal content when allow_all_users_to_flag_illegal_content" do
      UserSilencer.silence(user, admin)
      expect(Guardian.new(user).post_can_act?(post, :illegal)).to be false

      SiteSetting.email_address_to_report_illegal_content = "illegal@example.com"
      SiteSetting.allow_all_users_to_flag_illegal_content = true
      expect(Guardian.new(user).post_can_act?(post, :illegal)).to be true
      expect(Guardian.new(user).post_can_act?(post, :spam)).to be false
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
    it "returns false for a regular user allowed to see the post" do
      guardian = Guardian.new(user)

      guardian.stubs(:can_see_post?).returns(true)

      expect(guardian.can_lock_post?(post)).to be_falsey
    end

    it "returns false for a staff user not allowed to see the post" do
      guardian = Guardian.new(moderator)

      guardian.stubs(:can_see_post?).returns(false)

      expect(guardian.can_lock_post?(post)).to be_falsey
    end

    it "returns true for a staff user allowed to see the post" do
      guardian = Guardian.new(moderator)

      guardian.stubs(:can_see_post?).returns(true)

      expect(guardian.can_lock_post?(post)).to be_truthy
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
        it "allows a moderator to recover a post they deleted" do
          expect(Guardian.new(moderator).can_recover_post?(post)).to be_falsey

          PostDestroyer.new(moderator, post).destroy

          expect(Guardian.new(moderator).can_recover_post?(post.reload)).to be_truthy
        end

        describe "when post's user has been deleted" do
          it "allows a moderator to recover a post whose author was deleted" do
            PostDestroyer.new(moderator, post).destroy
            post.user.destroy!

            expect(Guardian.new(moderator).can_recover_post?(post.reload)).to be_truthy
          end
        end
      end
    end
  end

  describe "#can_unhide?" do
    it "returns false when the post is not hidden" do
      post.update!(hidden: false)

      expect(Guardian.new(moderator).can_unhide?(post)).to be_falsey
    end

    it "returns false for a regular user" do
      post.update!(hidden: true)

      expect(Guardian.new(user).can_unhide?(post)).to be_falsey
    end

    it "returns true for a staff user" do
      post.update!(hidden: true)

      expect(Guardian.new(moderator).can_unhide?(post)).to be_truthy
    end
  end

  describe "#can_skip_bump?" do
    it "returns false for a regular user" do
      expect(Guardian.new(user).can_skip_bump?).to be_falsey
    end

    it "returns true for a staff user" do
      expect(Guardian.new(moderator).can_skip_bump?).to be_truthy
    end

    it "returns true for a TL4 user" do
      expect(Guardian.new(trust_level_4).can_skip_bump?).to be_truthy
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
      fab!(:private_message) { Fabricate(:system_message_topic, user: user) }

      before { user.save! }

      it "allows the user to reply to system messages" do
        expect(Guardian.new(user).can_create_post?(private_message)).to eq(true)
        SiteSetting.enable_system_message_replies = false
        expect(Guardian.new(user).can_create_post?(private_message)).to eq(false)
      end

      it "allows replies from members of an allowed group" do
        group.add(groupless_user)
        private_message.topic_allowed_groups.create!(group: group)

        expect(groupless_user.guardian.can_create?(Post, private_message)).to eq(true)
      end
    end

    context "with private message" do
      fab!(:private_message, :private_message_topic)

      before { user.save! }

      it "allows new posts by people included in the pm" do
        private_message.topic_allowed_users.create!(user_id: user.id)
        expect(Guardian.new(user).can_create?(Post, private_message)).to be_truthy
      end

      it "allows new posts by people included via allowed groups" do
        group = Fabricate(:group)
        group.add(user)
        private_message.topic_allowed_groups.create!(group: group)

        expect(Guardian.new(user).can_create_post?(private_message)).to be_truthy
      end

      it "doesn't allow new posts by people not included in the pm" do
        expect(Guardian.new(user).can_create_post?(private_message)).to be_falsey
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

    context "when category group moderation is enabled" do
      before { SiteSetting.enable_category_group_moderation = true }

      it "returns false for a category group moderator who cannot see the topic" do
        mod_group = Fabricate(:group)
        cat_mod_user = Fabricate(:user)
        private_cat = Fabricate(:private_category, group: Fabricate(:group))
        private_t = Fabricate(:topic, category: private_cat)
        private_p = Fabricate(:post, topic: private_t)
        Fabricate(:category_moderation_group, category: private_cat, group: mod_group)
        mod_group.add(cat_mod_user)

        expect(Guardian.new(cat_mod_user).can_edit_post?(private_p)).to eq(false)
      end

      it "returns true for a category group moderator who can see the topic" do
        mod_group = Fabricate(:group)
        cat_mod_user = Fabricate(:user)
        private_cat = Fabricate(:private_category, group: mod_group)
        private_t = Fabricate(:topic, category: private_cat)
        private_p = Fabricate(:post, topic: private_t)
        Fabricate(:category_moderation_group, category: private_cat, group: mod_group)
        mod_group.add(cat_mod_user)

        expect(Guardian.new(cat_mod_user).can_edit_post?(private_p)).to eq(true)
      end
    end

    it "returns false for edit_all_post_groups user who cannot see the topic" do
      edit_group = Fabricate(:group)
      edit_user = Fabricate(:user)
      private_cat = Fabricate(:private_category, group: Fabricate(:group))
      private_t = Fabricate(:topic, category: private_cat)
      private_p = Fabricate(:post, topic: private_t)
      edit_group.add(edit_user)
      SiteSetting.edit_all_post_groups = edit_group.id.to_s

      expect(Guardian.new(edit_user).can_edit_post?(private_p)).to eq(false)
    end

    it "returns true even if the topic is closed" do
      topic.update!(closed: true)

      post.update!(user: user)
      guardian = Guardian.new(user)

      expect(guardian.can_edit?(post)).to be_truthy
    end

    it "returns false for the author of a wiki post hidden during the cooldown" do
      post.update!(user: user, wiki: true, hidden: true, hidden_at: Time.zone.now)

      expect(user.guardian.can_edit_post?(post)).to eq(false)
    end

    it "returns true for the author of a wiki post unhidden during the cooldown" do
      post.update!(user: user, wiki: true, hidden: false, hidden_at: Time.zone.now)

      expect(user.guardian.can_edit_post?(post)).to eq(true)
    end

    it "returns true for other wiki editors of a wiki post hidden during the cooldown" do
      post.update!(wiki: true, hidden: true, hidden_at: Time.zone.now)

      expect(user.guardian.can_edit_post?(post)).to eq(true)
    end
  end

  describe "#can_edit_hidden_post?" do
    it "returns true if the post is not hidden" do
      post.update!(hidden: false)

      expect(Guardian.new(user).can_edit_hidden_post?(post)).to be_truthy
    end

    it "returns true when the cooldown has passed" do
      post.update!(
        hidden: true,
        hidden_at: SiteSetting.cooldown_minutes_after_hiding_posts.minutes.ago - 1.minute,
      )

      expect(Guardian.new(user).can_edit_hidden_post?(post)).to be_truthy
    end

    it "returns false when the cooldown hasn't passed" do
      post.update!(
        hidden: true,
        hidden_at: SiteSetting.cooldown_minutes_after_hiding_posts.minutes.ago + 1.minute,
      )

      expect(Guardian.new(user).can_edit_hidden_post?(post)).to be_falsey
    end
  end

  describe "#can_change_post_owner?" do
    it "returns false for a regular user" do
      expect(Guardian.new(user).can_change_post_owner?).to be_falsey
    end

    it "returns true for an admin" do
      expect(Guardian.new(admin).can_change_post_owner?).to be_truthy
    end

    it "returns true for a moderator when allowed" do
      SiteSetting.moderators_change_post_ownership = true

      expect(Guardian.new(moderator).can_change_post_owner?).to be_truthy
    end

    it "returns false for a moderator when not allowed" do
      SiteSetting.moderators_change_post_ownership = false

      expect(Guardian.new(moderator).can_change_post_owner?).to be_falsey
    end

    describe "with allowed groups" do
      fab!(:allowed_group, :group)
      fab!(:allowed_group_user) { Fabricate(:user, groups: [allowed_group]) }

      before { SiteSetting.change_post_ownership_allowed_groups = "#{allowed_group.id}" }

      it "returns true for user in allowed group" do
        expect(Guardian.new(allowed_group_user).can_change_post_owner?).to be_truthy
      end

      it "returns false for user not in allowed group" do
        expect(Guardian.new(user).can_change_post_owner?).to be_falsy
      end
    end
  end

  describe "#can_change_post_timestamps?" do
    it "returns false for a regular user" do
      expect(Guardian.new(user).can_change_post_timestamps?).to be_falsey
    end

    it "returns true for a staff user" do
      expect(Guardian.new(moderator).can_change_post_timestamps?).to be_truthy
    end
  end

  describe "#trusted_with_post_edits?" do
    it "returns true for staff users" do
      SiteSetting.edit_post_allowed_groups = "1|2|14"

      expect(Guardian.new(moderator).trusted_with_post_edits?).to be_truthy
    end

    it "returns true for users in allowed groups" do
      SiteSetting.edit_post_allowed_groups = "1|2|14"

      expect(Guardian.new(trust_level_4).trusted_with_post_edits?).to be_truthy
    end

    it "returns false for users not in allowed groups" do
      SiteSetting.edit_post_allowed_groups = "1|2|14"

      expect(Guardian.new(trust_level_0).trusted_with_post_edits?).to be_falsey
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
      SiteSetting.edit_all_post_groups = ""

      expect(Guardian.new(user).is_in_edit_post_groups?).to eq(false)
    end
  end

  ###### DELETING ######

  describe "#can_delete_post?" do
    it "returns false if the user can't see the post" do
      guardian = Guardian.new(user)

      guardian.stubs(:can_see_post?).returns(false)

      expect(guardian.can_delete_post?(post)).to be_falsey
    end

    it "returns false if it's the first post of a topic" do
      expect(Guardian.new(admin).can_delete_post?(topic.first_post)).to be_falsey
    end

    it "returns true for a staff user" do
      expect(Guardian.new(moderator).can_delete_post?(second_post)).to be_truthy
    end

    it "returns true for a group category moderator" do
      guardian = Guardian.new(user)

      guardian.stubs(:is_category_group_moderator?).returns(true)

      expect(guardian.can_delete_post?(second_post)).to be_truthy
    end

    it "returns true for a user in allowed groups" do
      SiteSetting.delete_all_posts_and_topics_allowed_groups = "1|2|14"

      expect(Guardian.new(trust_level_4).can_delete_post?(second_post)).to be_truthy
    end

    it "returns false if the topic is archived" do
      topic.update!(archived: true)

      expect(Guardian.new(user).can_delete_post?(second_post)).to be_falsey
    end

    it "returns false for a regular user" do
      expect(Guardian.new(user).can_delete_post?(second_post)).to be_falsey
    end

    it "returns true for the post owner if not already deleted" do
      guardian = Guardian.new(user)

      guardian.stubs(:is_my_own?).returns(true)

      expect(guardian.can_delete_post?(second_post)).to be_truthy
    end

    it "returns false for the post owner if already deleted" do
      second_post.update!(user_deleted: true)

      guardian = Guardian.new(user)

      guardian.stubs(:is_my_own?).returns(true)

      expect(guardian.can_delete_post?(second_post)).to be_falsey
    end

    it "returns false for the post owner if rate limit set to zero" do
      SiteSetting.max_post_deletions_per_day = 0

      guardian = Guardian.new(user)

      guardian.stubs(:is_my_own?).returns(true)

      expect(guardian.can_delete_post?(second_post)).to be_falsey
    end
  end

  describe "#can_delete_post_or_topic?" do
    it "returns true when deleting first post and allowed to delete topics" do
      guardian = Guardian.new(user)

      guardian.stubs(:can_delete_topic?).returns(true)

      expect(guardian.can_delete_post_or_topic?(topic.first_post)).to be_truthy
    end

    it "returns false when deleting first post and not allowed to delete topics" do
      guardian = Guardian.new(user)

      guardian.stubs(:can_delete_topic?).returns(false)

      expect(guardian.can_delete_post_or_topic?(topic.first_post)).to be_falsey
    end

    it "returns true when deleting second post and allowed to delete posts" do
      guardian = Guardian.new(user)

      guardian.stubs(:can_delete_post?).returns(true)

      expect(guardian.can_delete_post_or_topic?(second_post)).to be_truthy
    end

    it "returns false when deleting second post and not allowed to delete posts" do
      guardian = Guardian.new(user)

      guardian.stubs(:can_delete_post?).returns(false)

      expect(guardian.can_delete_post_or_topic?(second_post)).to be_falsey
    end
  end

  describe "#can_permanently_delete_post?" do
    it "returns false whe permanent deletion is disabled" do
      SiteSetting.can_permanently_delete = false

      expect(Guardian.new(admin).can_permanently_delete_post?(second_post)).to be_falsey
    end

    it "returns false for the first post in the topic" do
      SiteSetting.can_permanently_delete = true

      expect(Guardian.new(admin).can_permanently_delete_post?(topic.first_post)).to be_falsey
    end

    it "returns false for a regular user" do
      SiteSetting.can_permanently_delete = true

      expect(Guardian.new(user).can_permanently_delete_post?(second_post)).to be_falsey
    end

    it "returns false if the post is not deleted" do
      SiteSetting.can_permanently_delete = true

      expect(Guardian.new(admin).can_permanently_delete_post?(second_post)).to be_falsey
    end

    it "returns false when the cooldown has not passed yet" do
      SiteSetting.can_permanently_delete = true

      second_post.update!(
        deleted_at: Post::PERMANENT_DELETE_TIMER.ago + 1.minute,
        deleted_by_id: admin.id,
      )

      expect(Guardian.new(admin).can_permanently_delete_post?(second_post)).to be_falsey
    end

    it "returns true when the cooldown has passed" do
      SiteSetting.can_permanently_delete = true

      second_post.update!(
        deleted_at: Post::PERMANENT_DELETE_TIMER.ago - 1.minute,
        deleted_by_id: admin.id,
      )

      expect(Guardian.new(admin).can_permanently_delete_post?(second_post)).to be_truthy
    end

    it "returns true within cooldown when original delete was by another user" do
      SiteSetting.can_permanently_delete = true

      second_post.update!(
        deleted_at: Post::PERMANENT_DELETE_TIMER.ago + 1.minute,
        deleted_by_id: moderator.id,
      )

      expect(Guardian.new(admin).can_permanently_delete_post?(second_post)).to be_truthy
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

      it "is false if user is a moderator" do
        another_moderator = Fabricate(:moderator, created_at: 1.day.ago)
        expect(Guardian.new(actor).can_delete_all_posts?(another_moderator)).to be_falsey
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

      it "is true if user is a moderator" do
        another_moderator = Fabricate(:moderator, created_at: 1.day.ago)
        expect(Guardian.new(actor).can_delete_all_posts?(another_moderator)).to be_truthy
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

    it "requires current whisper group membership" do
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

      regular_whisper = Fabricate(:post, post_type: Post.types[:whisper], user: regular_user)
      expect(regular_guardian.can_see?(regular_whisper)).to eq(false)

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

  describe "#filter_visible_posts" do
    def expect_post_scope_parity(posts, viewers)
      viewers.each do |viewer|
        guardian = viewer&.guardian || Guardian.new
        expected_ids = posts.select { |candidate| guardian.can_see_post?(candidate) }.map(&:id)
        expect(
          Post.with_deleted.where(id: posts.map(&:id)).secured(guardian).pluck(:id),
        ).to match_array(expected_ids),
        "viewer #{viewer&.id || "anonymous"}"
        posts
          .map(&:topic_id)
          .uniq
          .each do |topic_id|
            topic = Topic.with_deleted.find_by(id: topic_id)
            next if !topic
            candidates = Post.with_deleted.where(id: posts.map(&:id))
            expected_for_topic =
              posts
                .select do |candidate|
                  candidate.topic_id == topic_id && expected_ids.include?(candidate.id)
                end
                .map(&:id)
            expect(
              guardian.filter_visible_posts(candidates, topic: topic).pluck(:id),
            ).to match_array(expected_for_topic)
          end
      end
    end

    it "matches post types, hidden state, and deletion for every kind of viewer" do
      SiteSetting.enable_category_group_moderation = true
      SiteSetting.hidden_post_visible_groups = group.id.to_s
      SiteSetting.whispers_allowed_groups = "#{Group::AUTO_GROUPS[:staff]}|#{group.id}"
      category_moderator = Fabricate(:user, groups: [Fabricate(:group)])
      Fabricate(
        :category_moderation_group,
        category: category,
        group: category_moderator.groups.first,
      )
      staged = Fabricate(:user, staged: true)
      viewers = [
        nil,
        trust_level_0,
        trust_level_4,
        user,
        groupless_user,
        staged,
        moderator,
        admin,
        category_moderator,
      ]
      posts = []
      Post.types.each_value do |post_type|
        [false, true].product([false, true])
          .each do |hidden, deleted|
            [user, trust_level_4, staged].each do |author|
              posts << Fabricate(
                :post,
                topic: topic,
                user: author,
                post_type: post_type,
                hidden: hidden,
                deleted_at: deleted ? Time.current : nil,
                deleted_by_id: deleted ? author.id : nil,
              )
            end
          end
      end
      expect_post_scope_parity(posts, viewers)

      SiteSetting.whispers_allowed_groups = ""
      SiteSetting.enable_category_group_moderation = false
      expect_post_scope_parity(posts, viewers)
    end

    it "requires topic access before category moderator and post-state exceptions" do
      SiteSetting.enable_category_group_moderation = true
      private_category = Fabricate(:private_category, group: group)
      Fabricate(:category_moderation_group, category: private_category, group: group)
      private_topic = Fabricate(:topic, category: private_category)
      unlisted_topic = Fabricate(:topic, visible: false)
      shared_draft = Fabricate(:shared_draft)
      SiteSetting.shared_drafts_allowed_groups = Group::AUTO_GROUPS[:admins].to_s
      posts =
        [private_topic, unlisted_topic, shared_draft.topic].flat_map do |candidate_topic|
          [false, true].map { |hidden| Fabricate(:post, topic: candidate_topic, hidden: hidden) }
        end
      expect_post_scope_parity(posts, [nil, groupless_user, user, moderator, admin])
      expect(Post.secured(nil).where(topic_id: unlisted_topic.id).count).to eq(1)
      expect(Post.secured(user.guardian).where(topic_id: private_topic.id).count).to eq(2)
      expect(Post.secured(moderator.guardian).where(topic_id: shared_draft.topic_id)).to be_empty
    end

    it "resolves deleted topics consistently for lazy, preloaded, and assigned associations" do
      SiteSetting.enable_category_group_moderation = true
      Fabricate(:category_moderation_group, category: category, group: group)
      topic.trash!(admin)
      hidden_post.trash!(admin)
      lazy = Post.with_deleted.find(hidden_post.id)
      preloaded = Post.with_deleted.includes(:topic).find(hidden_post.id)
      assigned = Post.with_deleted.find(hidden_post.id)
      assigned.topic = Topic.with_deleted.find(topic.id)
      expect(lazy.topic).to be_nil
      expect(preloaded.topic).to be_nil
      [lazy, preloaded, assigned].each do |candidate|
        expect(user.guardian.can_see_post?(candidate)).to eq(true)
        expect(moderator.guardian.can_see_post?(candidate)).to eq(true)
      end
      expect_post_scope_parity(
        [lazy, Post.find(post.id)],
        [nil, user, groupless_user, moderator, admin],
      )

      SiteSetting.delete_all_posts_and_topics_allowed_groups = group.id.to_s
      SiteSetting.enable_category_group_moderation = false
      expect(user.guardian.can_see_post?(Post.find(post.id))).to eq(true)
      expect(user.guardian.can_see_post?(lazy)).to eq(false)
      expect_post_scope_parity([lazy, Post.find(post.id)], [nil, user, moderator, admin])
    end

    it "excludes deleted posts for authenticated anonymous-mode TL4 deleters" do
      SiteSetting.allow_anonymous_mode = true
      anon.update!(trust_level: TrustLevel[4])
      post.trash!(anon)
      expect(anon.anonymous?).to eq(true)
      expect(anon.guardian.can_see_deleted_post?(post)).to eq(false)
      expect_post_scope_parity([post], [anon])
      expect(Post.with_deleted.secured(anon.guardian).where(id: post.id)).to be_empty
    end

    it "memoizes deleted and missing topic lookups without loading or mutating associations" do
      Guardian.disable_post_can_see_consistency_check
      Guardian.disable_topic_can_see_consistency_check
      topic.trash!(admin)
      candidates = [Post.find(post.id), Post.find(second_post.id)]
      guardian = moderator.guardian
      queries =
        track_sql_queries do
          candidates.each do |candidate|
            2.times { expect(guardian.can_see_post?(candidate)).to eq(true) }
          end
        end
      expect(queries.grep(/SELECT "topics"\.\* FROM "topics"/).size).to eq(1)
      expect(candidates.map { |candidate| candidate.association(:topic).loaded? }).to eq(
        [false, false],
      )

      orphan = Fabricate(:post)
      orphan.update_columns(topic_id: -1000)
      orphan = Post.find(orphan.id)
      queries =
        track_sql_queries { 2.times { expect(guardian.can_see_post?(orphan)).to eq(false) } }
      expect(queries.grep(/SELECT "topics"\.\* FROM "topics"/).size).to eq(1)
      expect(orphan.association(:topic).loaded?).to eq(false)
    end

    it "honors an assigned unsaved topic and skips consistency checks for dirty posts" do
      post.hidden = true
      expect(user.guardian.can_see_post?(post)).to eq(false)
      Guardian.disable_topic_can_see_consistency_check
      assigned = Post.find(second_post.id)
      assigned.topic = Fabricate.build(:topic, category: category)
      guardian = user.guardian
      expect(guardian.can_see_post?(assigned)).to eq(true)
      expect(assigned.topic).to be_new_record
      private_category = Fabricate(:private_category, group: Fabricate(:group))
      assigned.topic = Fabricate.build(:topic, category: private_category)
      expect(guardian.can_see_post?(assigned)).to eq(false)
    end

    it "skips post consistency checks for dirty or new loaded topics without loading associations" do
      Guardian.disable_topic_can_see_consistency_check
      guardian = user.guardian
      unloaded = Post.find(post.id)
      expect(guardian.can_see_post?(unloaded)).to eq(true)
      expect(unloaded.association(:topic)).not_to be_loaded

      private_category = Fabricate(:private_category, group: Fabricate(:group))
      dirty = Post.find(post.id)
      dirty.topic.category = private_category
      expect(dirty).not_to have_changes_to_save
      expect(guardian.can_see_post?(dirty)).to eq(false)

      assigned = Post.find(post.id)
      assigned.association(:topic).target = Fabricate.build(:topic, category: private_category)
      expect(assigned).not_to have_changes_to_save
      expect(guardian.can_see_post?(assigned)).to eq(false)
    end

    it "supports an extension authorizing a post with no topic" do
      Guardian.disable_post_can_see_consistency_check
      orphan = Fabricate(:post)
      orphan.update_columns(topic_id: -1000)
      guardian = user.guardian
      guardian.define_singleton_method(:can_see_post_topic?) { |candidate| candidate.persisted? }

      expect(guardian.can_see_post?(Post.find(orphan.id))).to eq(true)
    end

    it "ignores stale association targets without mutating them" do
      old_topic = post.topic
      restricted =
        Fabricate(:topic, category: Fabricate(:private_category, group: Fabricate(:group)))
      post.update_columns(topic_id: restricted.id)
      expect(user.guardian.can_see_post?(post)).to eq(false)
      expect(post.association(:topic).target).to eq(old_topic)
      expect(post.association(:topic)).to be_stale_target
    end

    it "retains compatibility with single-argument topic predicate prepends" do
      guardian = user.guardian
      extension =
        Module.new do
          def can_see_post_topic?(post)
            post.persisted? && super
          end
        end
      guardian.singleton_class.prepend(extension)
      expect(guardian.can_see_post?(post)).to eq(true)
    end

    it "uses the deleter's trust level rather than authorship or the delete-all group" do
      SiteSetting.delete_all_posts_and_topics_allowed_groups = group.id.to_s
      post.trash!(trust_level_4)
      expect(
        Post.with_deleted.secured(trust_level_4.guardian).where(id: post.id),
      ).to contain_exactly(post)
      expect(Post.with_deleted.secured(user.guardian).where(id: post.id)).to be_empty
      post.update!(deleted_by_id: user.id)
      expect(Post.with_deleted.secured(user.guardian).where(id: post.id)).to be_empty
      user.update!(trust_level: TrustLevel[3])
      expect_post_scope_parity([post], [user, trust_level_4, moderator, admin])
    end

    it "matches direct and group PMs, moderator warnings, and pending flags without recursion" do
      direct = Fabricate(:private_message_topic, recipient: user)
      grouped = Fabricate(:group_private_message_topic, recipient_group: group)
      warning = Fabricate(:private_message_topic, subtype: TopicSubtype.moderator_warning)
      flagged = Fabricate(:private_message_topic)
      resolved = Fabricate(:private_message_topic)
      ignored = Fabricate(:private_message_topic)
      Fabricate(:reviewable_flagged_post, topic: flagged, category: nil)
      Fabricate(:reviewable_flagged_post, topic: resolved, category: nil, status: :rejected)
      Fabricate(:reviewable_flagged_post, topic: ignored, category: nil, score: -1)
      Fabricate(:shared_draft, topic: direct)
      SiteSetting.shared_drafts_allowed_groups = Group::AUTO_GROUPS[:admins].to_s
      posts =
        [direct, grouped, warning, flagged, resolved, ignored].map do |pm|
          Fabricate(:post, topic: pm)
        end
      expect_post_scope_parity(posts, [nil, user, groupless_user, moderator, admin])
      expect(
        Post.secured(moderator.guardian).where(id: posts.map(&:id)).pluck(:topic_id),
      ).to contain_exactly(warning.id, flagged.id)
      expect(
        Post.secured(user.guardian).where(id: posts.map(&:id)).pluck(:topic_id),
      ).to contain_exactly(direct.id, grouped.id)
    end

    it "matches staged users in their own email-in restricted topics, including blank addresses" do
      SiteSetting.email_in = true
      staged = Fabricate(:user, staged: true)
      restricted =
        Fabricate(
          :private_category,
          group: group,
          email_in: "inbound@example.com",
          email_in_allow_strangers: true,
        )
      own_topic = Fabricate(:topic, category: restricted, user: staged)
      own_post = Fabricate(:post, topic: own_topic, user: staged)
      other_post = Fabricate(:post, topic: Fabricate(:topic, category: restricted))
      expect(
        Post.secured(staged.guardian).where(id: [own_post.id, other_post.id]),
      ).to contain_exactly(own_post)
      [nil, "", "   ", "\t\r\n\f\v"].each do |email_in|
        restricted.update_columns(email_in: email_in)
        expect(Post.secured(staged.guardian).where(id: own_post.id)).to be_empty
        expect_post_scope_parity([Post.find(own_post.id)], [staged])
      end
      ["\u00a0", "\u3000"].each do |email_in|
        restricted.update_columns(email_in: email_in)
        expect_post_scope_parity([Post.find(own_post.id)], [staged])
      end
    end

    it "matches anonymous hidden-group permissions with and without granular groups" do
      [Group::AUTO_GROUPS[:everyone], Group::AUTO_GROUPS[:anonymous_users]].each do |group_id|
        SiteSetting.stubs(:hidden_post_visible_groups_map).returns([group_id])
        [false, true].each do |enabled|
          SiteSetting.granular_anonymous_and_logged_in_groups_permissions = enabled
          expect_post_scope_parity([post, hidden_post], [nil, user])
          expected = enabled && group_id == Group::AUTO_GROUPS[:anonymous_users]
          expect(Post.secured(nil).where(id: hidden_post.id).exists?).to eq(expected)
        end
      end
    end

    it "preserves the unconditional admin bypass for suppressed categories, whispers, and orphans" do
      SiteSetting.suppress_secured_categories_from_admin = true
      SiteSetting.whispers_allowed_groups = ""
      restricted = Fabricate(:private_category, group: group)
      private_post =
        Fabricate(
          :post,
          topic: Fabricate(:topic, category: restricted),
          post_type: Post.types[:whisper],
          hidden: true,
          deleted_at: Time.current,
        )
      pm_post = Fabricate(:post, topic: Fabricate(:private_message_topic))
      orphan = Fabricate(:post)
      DB.exec("DELETE FROM topics WHERE id = ?", orphan.topic_id)
      orphan.reload
      expect_post_scope_parity(
        [private_post, pm_post, orphan],
        [nil, groupless_user, moderator, admin],
      )
      expect(
        Post
          .with_deleted
          .secured(admin.guardian)
          .where(id: [private_post.id, pm_post.id, orphan.id]),
      ).to contain_exactly(private_post, pm_post, orphan)
    end

    it "keeps reviewable scopes type-only with a single topic visibility predicate" do
      guardian = moderator.guardian
      topics = guardian.visible_topic_scope(Topic.with_deleted.where("topics.id = posts.topic_id"))
      baseline =
        Post
          .with_deleted
          .where("posts.post_type IN (?)", Topic.visible_post_types(moderator))
          .where("EXISTS (#{topics.select(1).to_sql})")
      expect(guardian.reviewable_post_scope.to_sql).to eq(baseline.to_sql)
    end
  end

  describe "#filter_hidden_posts" do
    before { SiteSetting.hidden_post_visible_groups = "" }

    it "returns only visible posts for anonymous users" do
      records = Post.where(id: [post.id, hidden_post.id])

      expect(Guardian.new.filter_hidden_posts(records)).to contain_exactly(post)
    end

    it "returns visible posts and the user's hidden posts for regular users" do
      own_hidden_post = Fabricate(:post, topic: topic, user: user, hidden: true)
      records = Post.where(id: [post.id, hidden_post.id, own_hidden_post.id])

      expect(Guardian.new(user).filter_hidden_posts(records)).to contain_exactly(
        post,
        own_hidden_post,
      )
    end

    it "returns hidden posts for staff users" do
      records = Post.where(id: [post.id, hidden_post.id])

      expect(Guardian.new(moderator).filter_hidden_posts(records)).to contain_exactly(
        post,
        hidden_post,
      )
    end

    it "returns hidden posts for members of hidden_post_visible_groups" do
      SiteSetting.hidden_post_visible_groups = group.id.to_s
      records = Post.where(id: [post.id, hidden_post.id])

      expect(Guardian.new(user).filter_hidden_posts(records)).to contain_exactly(post, hidden_post)
    end

    it "does not return hidden posts for anonymous users configured via everyone" do
      SiteSetting.hidden_post_visible_groups = Group::AUTO_GROUPS[:everyone].to_s
      records = Post.where(id: [post.id, hidden_post.id])

      expect(Guardian.new.filter_hidden_posts(records)).to contain_exactly(post)
    end

    it "returns hidden posts from moderated categories for category group moderators" do
      SiteSetting.enable_category_group_moderation = true
      Fabricate(:category_moderation_group, category: category, group: group)
      unmoderated_visible_post = Fabricate(:post)
      unmoderated_hidden_post =
        Fabricate(:post, topic: unmoderated_visible_post.topic, hidden: true)
      records =
        Post.joins(:topic).where(
          id: [post.id, hidden_post.id, unmoderated_visible_post.id, unmoderated_hidden_post.id],
        )

      expect(Guardian.new(user).filter_hidden_posts(records)).to contain_exactly(
        post,
        hidden_post,
        unmoderated_visible_post,
      )
    end

    it "returns hidden posts in the category for category group moderators" do
      SiteSetting.enable_category_group_moderation = true
      Fabricate(:category_moderation_group, category: category, group: group)
      records = Post.where(id: [post.id, hidden_post.id])

      expect(
        Guardian.new(user).filter_hidden_posts(records, category: category),
      ).to contain_exactly(post, hidden_post)
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

  describe "#can_see_deleted_posts_for_user?" do
    it "returns true for staff" do
      expect(Guardian.new(admin).can_see_deleted_posts_for_user?).to eq(true)
      expect(Guardian.new(moderator).can_see_deleted_posts_for_user?).to eq(true)
    end

    it "returns false for non-staff users in delete_all_posts_and_topics_allowed_groups" do
      SiteSetting.delete_all_posts_and_topics_allowed_groups = Group::AUTO_GROUPS[:trust_level_4]

      expect(Guardian.new(trust_level_4).can_see_deleted_posts_for_user?).to eq(false)
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
    it "resolves deleted topics for category moderators without mutating the association" do
      SiteSetting.edit_history_visible_to_public = false
      SiteSetting.enable_category_group_moderation = true
      Fabricate(:category_moderation_group, category: category, group: group)
      topic.trash!(admin)
      candidate = Post.find(post.id)
      expect(user.guardian.can_view_edit_history?(candidate)).to eq(true)
      expect(candidate.association(:topic).loaded?).to eq(false)
    end

    it "returns true for wiki posts" do
      post.update!(wiki: true)

      expect(Guardian.new(user).can_view_edit_history?(post)).to be_truthy
    end

    it "returns true when edit history is configured to be public" do
      SiteSetting.edit_history_visible_to_public = true

      expect(Guardian.new(user).can_view_edit_history?(post)).to be_truthy
    end

    it "returns true for staff viewing a hidden post" do
      post.update!(hidden: true)

      expect(Guardian.new(admin).can_view_edit_history?(post)).to be_truthy
    end

    it "returns true for post owner viewing a hidden post" do
      post.update!(hidden: true)

      expect(Guardian.new(post.user).can_view_edit_history?(post)).to be_truthy
    end

    it "returns true for a category group moderator viewing a hidden post" do
      SiteSetting.edit_history_visible_to_public = true
      SiteSetting.enable_category_group_moderation = true
      Fabricate(:category_moderation_group, category: category, group:)
      post.update!(hidden: true)

      expect(Guardian.new(user).can_view_edit_history?(post)).to be_truthy
    end

    it "returns false when user can not see post" do
      post.update!(hidden: true)

      guardian = Guardian.new(moderator)

      guardian.stubs(:can_see_post?).returns(false)

      expect(guardian.can_view_edit_history?(post)).to be_falsey
    end

    context "when edit_history_visible_to_public is false" do
      before { SiteSetting.edit_history_visible_to_public = false }

      it "returns false for a regular user" do
        expect(Guardian.new(user).can_view_edit_history?(post)).to be_falsey
      end

      it "returns true for a category group moderator" do
        SiteSetting.enable_category_group_moderation = true
        Fabricate(:category_moderation_group, category: category, group:)

        expect(Guardian.new(user).can_view_edit_history?(post)).to be_truthy
      end

      it "returns false for a category group moderator in a different category" do
        SiteSetting.enable_category_group_moderation = true
        other_category = Fabricate(:category)
        Fabricate(:category_moderation_group, category: other_category, group:)

        expect(Guardian.new(user).can_view_edit_history?(post)).to be_falsey
      end

      it "returns false for a category group moderator when feature is disabled" do
        SiteSetting.enable_category_group_moderation = false
        Fabricate(:category_moderation_group, category: category, group:)

        expect(Guardian.new(user).can_view_edit_history?(post)).to be_falsey
      end
    end
  end

  describe "#can_view_raw_email?" do
    it "returns true for a user in an allowed group" do
      SiteSetting.view_raw_email_allowed_groups = "1|2|14"

      expect(Guardian.new(trust_level_4).can_view_raw_email?(post)).to be_truthy
    end

    it "returns false for a user not in an allowed group" do
      SiteSetting.view_raw_email_allowed_groups = "1|2|14"

      expect(Guardian.new(trust_level_0).can_view_raw_email?(post)).to be_falsey
    end

    it "returns false when the post is nil even for an allowed user" do
      SiteSetting.view_raw_email_allowed_groups = "1|2|14"

      expect(Guardian.new(trust_level_4).can_view_raw_email?(nil)).to be_falsey
    end
  end

  describe "#can_view_raw_emails?" do
    it "returns true for a user in an allowed group" do
      SiteSetting.view_raw_email_allowed_groups = "1|2|14"

      expect(Guardian.new(trust_level_4).can_view_raw_emails?).to be_truthy
    end

    it "returns false for a user not in an allowed group" do
      SiteSetting.view_raw_email_allowed_groups = "1|2|14"

      expect(Guardian.new(trust_level_0).can_view_raw_emails?).to be_falsey
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

    it "allows admin notifications for an in-memory topic without a category" do
      SiteSetting.suppress_secured_categories_from_admin = true
      post.topic.category = nil

      expect(admin.guardian.can_receive_post_notifications?(post)).to eq(true)
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
