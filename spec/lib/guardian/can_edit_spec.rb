# frozen_string_literal: true

RSpec.describe Guardian, "#can_edit?" do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:another_user, :user)
  fab!(:member, :user)
  fab!(:owner, :user)
  fab!(:moderator) { Fabricate(:moderator, refresh_auto_groups: true) }
  fab!(:admin)
  fab!(:anonymous_user, :anonymous)
  fab!(:staff_post) { Fabricate(:post, user: moderator) }
  fab!(:group)
  fab!(:another_group, :group)
  fab!(:automatic_group) { Fabricate(:group, automatic: true) }
  fab!(:plain_category, :category)

  fab!(:trust_level_0)
  fab!(:trust_level_1)
  fab!(:trust_level_2)
  fab!(:trust_level_3)
  fab!(:trust_level_4) { Fabricate(:trust_level_4, refresh_auto_groups: true) }
  fab!(:another_admin, :admin)
  fab!(:coding_horror) { Fabricate(:coding_horror, refresh_auto_groups: true) }

  fab!(:topic) { Fabricate(:topic, user: user) }
  fab!(:post) { Fabricate(:post, topic: topic, user: topic.user) }

  before { Guardian.enable_topic_can_see_consistency_check }

  after { Guardian.disable_topic_can_see_consistency_check }

  it "returns false with a nil object" do
    expect(Guardian.new(user).can_edit?(nil)).to be_falsey
  end

  describe "a Post" do
    it "returns false for silenced users" do
      post.user.silenced_till = 1.day.from_now
      expect(Guardian.new(post.user).can_edit?(post)).to be_falsey
    end

    it "returns false when not logged in" do
      expect(Guardian.new.can_edit?(post)).to be_falsey
    end

    it "returns false when not logged in also for wiki post" do
      post.wiki = true
      expect(Guardian.new.can_edit?(post)).to be_falsey
    end

    it "returns true if you want to edit your own post" do
      expect(Guardian.new(post.user).can_edit?(post)).to be_truthy
    end

    it "returns false if you try to edit a locked post" do
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

    it "returns false if you are trying to edit a post you soft deleted" do
      post.user_deleted = true
      expect(Guardian.new(post.user).can_edit?(post)).to be_falsey
    end

    it "returns false if another regular user tries to edit a soft deleted wiki post" do
      post.wiki = true
      post.user_deleted = true
      expect(Guardian.new(coding_horror).can_edit?(post)).to be_falsey
    end

    it "returns false if you are trying to edit a deleted post" do
      post.deleted_at = 1.day.ago
      expect(Guardian.new(post.user).can_edit?(post)).to be_falsey
    end

    it "returns false if another regular user tries to edit a deleted wiki post" do
      post.wiki = true
      post.deleted_at = 1.day.ago
      expect(Guardian.new(coding_horror).can_edit?(post)).to be_falsey
    end

    it "returns false if another regular user tries to edit your post" do
      expect(Guardian.new(coding_horror).can_edit?(post)).to be_falsey
    end

    it "returns true if another regular user tries to edit wiki post" do
      post.wiki = true
      expect(Guardian.new(coding_horror).can_edit?(post)).to be_truthy
    end

    it "returns false if a wiki but the user can't create a post" do
      c = plain_category
      c.set_permissions(everyone: :readonly)
      c.save

      topic = Fabricate(:topic, category: c)
      post = Fabricate(:post, topic: topic)
      post.wiki = true

      expect(Guardian.new(user).can_edit?(post)).to eq(false)
    end

    it "returns true as a moderator" do
      expect(Guardian.new(moderator).can_edit?(post)).to be_truthy
    end

    it "returns true as a moderator, even if locked" do
      post.locked_by_id = admin.id
      expect(Guardian.new(moderator).can_edit?(post)).to be_truthy
    end

    it "returns true as an admin" do
      expect(Guardian.new(admin).can_edit?(post)).to be_truthy
    end

    it "returns true as a trust level 4 user" do
      expect(Guardian.new(trust_level_4).can_edit?(post)).to be_truthy
    end

    it "returns false when trying to edit a topic when the user is not in the allowed groups" do
      SiteSetting.edit_post_allowed_groups = Group::AUTO_GROUPS[:trust_level_2]
      post.user.change_trust_level!(TrustLevel[1])

      expect(Guardian.new(topic.user).can_edit?(topic)).to be_falsey
    end

    it "returns false when trying to edit a post when the user is not in the allowed groups" do
      SiteSetting.edit_post_allowed_groups = Group::AUTO_GROUPS[:trust_level_2]
      post.user.change_trust_level!(TrustLevel[1])

      expect(Guardian.new(post.user).can_edit?(post)).to be_falsey
    end

    it "returns true when editing a post when the user is in the allowed groups" do
      SiteSetting.edit_post_allowed_groups = Group::AUTO_GROUPS[:trust_level_1]
      post.user.change_trust_level!(TrustLevel[1])

      expect(Guardian.new(post.user).can_edit?(post)).to be_truthy
    end

    it "returns true when editing a post when the user is admin regardless of groups" do
      SiteSetting.edit_post_allowed_groups = Group::AUTO_GROUPS[:trust_level_2]
      post.user.update!(admin: true)
      post.user.change_trust_level!(TrustLevel[1])

      expect(Guardian.new(post.user).can_edit?(post)).to be_truthy
    end

    it "returns false when another user is not member of edit wiki post group" do
      SiteSetting.edit_wiki_post_allowed_groups = Group::AUTO_GROUPS[:trust_level_2]
      post.wiki = true
      Group.user_trust_level_change!(coding_horror.id, 1)

      expect(Guardian.new(coding_horror).can_edit?(post)).to be_falsey
    end

    it "returns true when another user is member of edit wiki post group" do
      SiteSetting.edit_wiki_post_allowed_groups = Group::AUTO_GROUPS[:trust_level_2]
      post.wiki = true
      Group.user_trust_level_change!(coding_horror.id, 2)

      expect(Guardian.new(coding_horror).can_edit?(post)).to be_truthy
    end

    it "returns true for post author even when author is not member of edit wiki post group" do
      SiteSetting.edit_wiki_post_allowed_groups = Group::AUTO_GROUPS[:trust_level_2]
      post.wiki = true
      Group.user_trust_level_change!(post.user, 1)

      expect(Guardian.new(post.user).can_edit?(post)).to be_truthy
    end

    context "with shared drafts" do
      fab!(:category)

      let(:topic) { Fabricate(:topic, category: category) }
      let(:post_with_draft) { Fabricate(:post, topic: topic) }

      before do
        SiteSetting.shared_drafts_category = category.id
        SiteSetting.shared_drafts_allowed_groups = Group::AUTO_GROUPS[:trust_level_2]
        Fabricate(:shared_draft, topic: topic)
      end

      it "returns true if a shared draft exists" do
        expect(Guardian.new(trust_level_2).can_edit_post?(post_with_draft)).to eq(true)
      end

      it "returns false if the user has a lower trust level" do
        expect(Guardian.new(trust_level_1).can_edit_post?(post_with_draft)).to eq(false)
      end

      it "returns false if the draft is from a different category" do
        topic.update!(category: Fabricate(:category))

        expect(Guardian.new(trust_level_2).can_edit_post?(post_with_draft)).to eq(false)
      end
    end

    context "when category group moderation is enabled" do
      fab!(:cat_mod_user, :user)

      before do
        SiteSetting.enable_category_group_moderation = true
        GroupUser.create!(group_id: group.id, user_id: cat_mod_user.id)
        Fabricate(:category_moderation_group, category: post.topic.category, group:)
      end

      it "returns true as a category group moderator user" do
        expect(Guardian.new(cat_mod_user).can_edit?(post)).to eq(true)
      end

      it "returns false for a regular user" do
        expect(Guardian.new(another_user).can_edit?(post)).to eq(false)
      end
    end

    describe "post edit time limits" do
      context "when post is older than post_edit_time_limit" do
        let(:user) { Fabricate(:user, refresh_auto_groups: true) }
        let(:topic) { Fabricate(:topic, user: user) }
        let(:old_post) do
          Fabricate(:post, topic: topic, user: topic.user, created_at: 6.minutes.ago)
        end
        let(:owner) { old_post.user }

        before do
          topic.user.update_columns(trust_level: 1)
          SiteSetting.post_edit_time_limit = 5
        end

        it "returns false to the author of the post" do
          expect(Guardian.new(old_post.user).can_edit?(old_post)).to be_falsey
        end

        it "returns true as a moderator" do
          expect(Guardian.new(moderator).can_edit?(old_post)).to eq(true)
        end

        it "returns true as an admin" do
          expect(Guardian.new(admin).can_edit?(old_post)).to eq(true)
        end

        it "returns false for another regular user trying to edit your post" do
          expect(Guardian.new(coding_horror).can_edit?(old_post)).to be_falsey
        end

        it "returns true for another regular user trying to edit a wiki post" do
          old_post.wiki = true
          expect(Guardian.new(coding_horror).can_edit?(old_post)).to be_truthy
        end

        it "returns true when the post topic's category allow_unlimited_owner_edits_on_first_post" do
          old_post.topic.category.update(allow_unlimited_owner_edits_on_first_post: true)
          expect(Guardian.new(owner).can_edit?(old_post)).to be_truthy
        end

        it "returns false when the post topic's category does not allow_unlimited_owner_edits_on_first_post" do
          old_post.topic.category.update(allow_unlimited_owner_edits_on_first_post: false)
          expect(Guardian.new(owner).can_edit?(old_post)).to be_falsey
        end

        it "returns false when the post topic's category allow_unlimited_owner_edits_on_first_post but the post is not the first in the topic" do
          old_post.topic.category.update(allow_unlimited_owner_edits_on_first_post: true)
          new_post = Fabricate(:post, user: owner, topic: old_post.topic, created_at: 6.minutes.ago)
          expect(Guardian.new(owner).can_edit?(new_post)).to be_falsey
        end

        it "returns false when someone other than owner is editing and category allow_unlimited_owner_edits_on_first_post" do
          old_post.topic.category.update(allow_unlimited_owner_edits_on_first_post: false)
          expect(Guardian.new(coding_horror).can_edit?(old_post)).to be_falsey
        end
      end

      context "when post is older than tl2_post_edit_time_limit" do
        let(:old_post) do
          Fabricate(:post, topic: topic, user: topic.user, created_at: 12.minutes.ago)
        end

        before do
          topic.user.update_columns(trust_level: 2)
          SiteSetting.tl2_post_edit_time_limit = 10
        end

        it "returns false to the author of the post" do
          expect(Guardian.new(old_post.user).can_edit?(old_post)).to be_falsey
        end

        it "returns true as a moderator" do
          expect(Guardian.new(moderator).can_edit?(old_post)).to eq(true)
        end

        it "returns true as an admin" do
          expect(Guardian.new(admin).can_edit?(old_post)).to eq(true)
        end

        it "returns false for another regular user trying to edit your post" do
          expect(Guardian.new(coding_horror).can_edit?(old_post)).to be_falsey
        end

        it "returns true for another regular user trying to edit a wiki post" do
          old_post.wiki = true
          expect(Guardian.new(coding_horror).can_edit?(old_post)).to be_truthy
        end
      end
    end

    context "with first post of a static page doc" do
      let!(:tos_topic) { Fabricate(:topic, user: Discourse.system_user) }
      let!(:tos_first_post) { Fabricate(:post, topic: tos_topic, user: tos_topic.user) }

      before { SiteSetting.tos_topic_id = tos_topic.id }

      it "restricts static doc posts" do
        expect(Guardian.new(Fabricate(:user)).can_edit?(tos_first_post)).to be_falsey
        expect(Guardian.new(moderator).can_edit?(tos_first_post)).to be_falsey
        expect(Guardian.new(admin).can_edit?(tos_first_post)).to be_truthy
      end
    end
  end

  describe "a Topic" do
    it "returns false when not logged in" do
      expect(Guardian.new.can_edit?(topic)).to be_falsey
    end

    it "returns true for editing your own post" do
      expect(Guardian.new(topic.user).can_edit?(topic)).to eq(true)
    end

    it "returns false as a regular user" do
      expect(Guardian.new(coding_horror).can_edit?(topic)).to be_falsey
    end

    context "when first post is hidden" do
      let!(:topic) { Fabricate(:topic, user: user) }

      before do
        Fabricate(:post, topic: topic, user: topic.user, hidden: true, hidden_at: Time.zone.now)
      end

      it "returns false for editing your own post while inside the cooldown window" do
        SiteSetting.cooldown_minutes_after_hiding_posts = 30

        expect(Guardian.new(topic.user).can_edit?(topic)).to eq(false)
      end
    end

    context "when locked" do
      let(:post) { Fabricate(:post, locked_by_id: admin.id) }
      let(:topic) { post.topic }

      it "doesn't allow users to edit locked topics" do
        expect(Guardian.new(topic.user).can_edit?(topic)).to eq(false)
        expect(Guardian.new(admin).can_edit?(topic)).to eq(true)
      end
    end

    context "when not archived" do
      it "returns true as a moderator" do
        expect(Guardian.new(moderator).can_edit?(topic)).to eq(true)
      end

      it "returns true as an admin" do
        expect(Guardian.new(admin).can_edit?(topic)).to eq(true)
      end

      it "returns true at trust level 3" do
        expect(Guardian.new(trust_level_3).can_edit?(topic)).to eq(true)
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

    context "with private message" do
      fab!(:private_message, :private_message_topic)

      it "returns false at trust level 3" do
        expect(Guardian.new(trust_level_3).can_edit?(private_message)).to eq(false)
      end

      it "returns false at trust level 4" do
        expect(Guardian.new(trust_level_4).can_edit?(private_message)).to eq(false)
      end
    end

    context "when archived" do
      let(:archived_topic) { Fabricate(:topic, user: user, archived: true) }

      it "returns true as a moderator" do
        expect(Guardian.new(moderator).can_edit?(archived_topic)).to be_truthy
      end

      it "returns true as an admin" do
        expect(Guardian.new(admin).can_edit?(archived_topic)).to be_truthy
      end

      it "returns true at trust level 4" do
        expect(Guardian.new(trust_level_4).can_edit?(archived_topic)).to be_truthy
      end

      it "returns true if the user is in edit_all_post_groups" do
        SiteSetting.edit_all_post_groups = "14"
        expect(Guardian.new(trust_level_4).can_edit?(archived_topic)).to eq(true)
      end

      it "returns false if the user is not in edit_all_post_groups" do
        SiteSetting.edit_all_post_groups = "14"
        expect(Guardian.new(trust_level_3).can_edit?(archived_topic)).to eq(false)
      end

      it "returns false at trust level 3" do
        expect(Guardian.new(trust_level_3).can_edit?(archived_topic)).to be_falsey
      end

      it "returns false as a topic creator" do
        expect(Guardian.new(user).can_edit?(archived_topic)).to be_falsey
      end
    end

    context "when very old" do
      let(:old_topic) { Fabricate(:topic, user: user, created_at: 6.minutes.ago) }

      before { SiteSetting.post_edit_time_limit = 5 }

      it "returns true as a moderator" do
        expect(Guardian.new(moderator).can_edit?(old_topic)).to be_truthy
      end

      it "returns true as an admin" do
        expect(Guardian.new(admin).can_edit?(old_topic)).to be_truthy
      end

      it "returns true at trust level 3" do
        expect(Guardian.new(trust_level_3).can_edit?(old_topic)).to be_truthy
      end

      it "returns false as a topic creator" do
        expect(Guardian.new(user).can_edit?(old_topic)).to be_falsey
      end
    end
  end

  describe "a Category" do
    it "returns false when not logged in" do
      expect(Guardian.new.can_edit?(plain_category)).to be_falsey
    end

    it "returns false as a regular user" do
      expect(Guardian.new(plain_category.user).can_edit?(plain_category)).to be_falsey
    end

    it "returns false as a moderator" do
      expect(Guardian.new(moderator).can_edit?(plain_category)).to be_falsey
    end

    it "returns true as an admin" do
      expect(Guardian.new(admin).can_edit?(plain_category)).to be_truthy
    end
  end

  describe "a User" do
    it "returns false when not logged in" do
      expect(Guardian.new.can_edit?(user)).to be_falsey
    end

    it "returns false as a different user" do
      expect(Guardian.new(coding_horror).can_edit?(user)).to be_falsey
    end

    it "returns true when trying to edit yourself" do
      expect(Guardian.new(user).can_edit?(user)).to be_truthy
    end

    it "returns true as a moderator" do
      expect(Guardian.new(moderator).can_edit?(user)).to be_truthy
    end

    it "returns true as an admin" do
      expect(Guardian.new(admin).can_edit?(user)).to be_truthy
    end
  end
end
