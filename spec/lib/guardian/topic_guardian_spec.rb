# frozen_string_literal: true

RSpec.describe TopicGuardian do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:admin)
  fab!(:tl3_user) { Fabricate(:trust_level_3) }
  fab!(:tl4_user) { Fabricate(:trust_level_4) }
  fab!(:moderator)
  fab!(:category)
  fab!(:group)
  fab!(:private_category) { Fabricate(:private_category, group: group) }
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:private_topic) { Fabricate(:topic, category: private_category) }
  fab!(:private_message_topic)

  before { Guardian.enable_topic_can_see_consistency_check }

  after { Guardian.disable_topic_can_see_consistency_check }

  describe "#can_create_shared_draft?" do
    it "when shared_drafts are disabled" do
      SiteSetting.shared_drafts_allowed_groups = Group::AUTO_GROUPS[:admins]

      expect(Guardian.new(admin).can_create_shared_draft?).to eq(false)
    end

    it "when user is a moderator and access is set to admin" do
      SiteSetting.shared_drafts_category = category.id
      SiteSetting.shared_drafts_allowed_groups = Group::AUTO_GROUPS[:admins]

      expect(Guardian.new(moderator).can_create_shared_draft?).to eq(false)
    end

    it "when user is a moderator and access is set to staff" do
      SiteSetting.shared_drafts_category = category.id
      SiteSetting.shared_drafts_allowed_groups = Group::AUTO_GROUPS[:staff]

      expect(Guardian.new(moderator).can_create_shared_draft?).to eq(true)
    end

    it "when user is TL3 and access is set to TL2" do
      SiteSetting.shared_drafts_category = category.id
      SiteSetting.shared_drafts_allowed_groups = Group::AUTO_GROUPS[:trust_level_2]

      expect(Guardian.new(tl3_user).can_create_shared_draft?).to eq(true)
    end
  end

  describe "#can_see_shared_draft?" do
    it "when shared_drafts are disabled (existing shared drafts)" do
      SiteSetting.shared_drafts_allowed_groups = Group::AUTO_GROUPS[:admins]

      expect(Guardian.new(admin).can_see_shared_draft?).to eq(true)
    end

    it "when user is a moderator and access is set to admin" do
      SiteSetting.shared_drafts_category = category.id
      SiteSetting.shared_drafts_allowed_groups = Group::AUTO_GROUPS[:admins]

      expect(Guardian.new(moderator).can_see_shared_draft?).to eq(false)
    end

    it "when user is a moderator and access is set to staff" do
      SiteSetting.shared_drafts_category = category.id
      SiteSetting.shared_drafts_allowed_groups = Group::AUTO_GROUPS[:staff]

      expect(Guardian.new(moderator).can_see_shared_draft?).to eq(true)
    end

    it "when user is TL3 and access is set to TL2" do
      SiteSetting.shared_drafts_category = category.id
      SiteSetting.shared_drafts_allowed_groups = Group::AUTO_GROUPS[:trust_level_2]

      expect(Guardian.new(tl3_user).can_see_shared_draft?).to eq(true)
    end
  end

  describe "#can_see_deleted_topics?" do
    it "returns true for staff" do
      expect(Guardian.new(admin).can_see_deleted_topics?(topic.category)).to eq(true)
    end

    it "returns true for group moderator" do
      SiteSetting.enable_category_group_moderation = true
      expect(Guardian.new(user).can_see_deleted_topics?(topic.category)).to eq(false)
      Fabricate(:category_moderation_group, category:, group:)
      group.add(user)
      topic.update!(category: category)
      expect(Guardian.new(user).can_see_deleted_topics?(topic.category)).to eq(true)
    end

    it "returns true when tl4 can delete posts and topics" do
      expect(Guardian.new(tl4_user).can_see_deleted_topics?(topic.category)).to eq(false)
      SiteSetting.delete_all_posts_and_topics_allowed_groups = Group::AUTO_GROUPS[:trust_level_4]
      expect(Guardian.new(tl4_user).can_see_deleted_topics?(topic.category)).to eq(true)
    end

    it "returns false for anonymous user" do
      SiteSetting.delete_all_posts_and_topics_allowed_groups = Group::AUTO_GROUPS[:trust_level_4]
      expect(Guardian.new.can_see_deleted_topics?(topic.category)).to be_falsey
    end
  end

  describe "#can_recover_topic?" do
    fab!(:deleted_topic) { Fabricate(:topic, category: category, deleted_at: 1.day.ago) }
    it "returns true for staff" do
      expect(Guardian.new(admin).can_recover_topic?(Topic.with_deleted.last)).to eq(true)
    end

    it "returns true for group moderator" do
      SiteSetting.enable_category_group_moderation = true
      expect(Guardian.new(user).can_recover_topic?(Topic.with_deleted.last)).to eq(false)
      Fabricate(:category_moderation_group, category:, group:)
      group.add(user)
      topic.update!(category: category)
      expect(Guardian.new(user).can_recover_topic?(Topic.with_deleted.last)).to eq(true)
    end

    it "returns true when tl4 can delete posts and topics" do
      expect(Guardian.new(tl4_user).can_recover_topic?(Topic.with_deleted.last)).to eq(false)
      SiteSetting.delete_all_posts_and_topics_allowed_groups = Group::AUTO_GROUPS[:trust_level_4]
      expect(Guardian.new(tl4_user).can_recover_topic?(Topic.with_deleted.last)).to eq(true)
    end

    it "returns false for anonymous user" do
      SiteSetting.delete_all_posts_and_topics_allowed_groups = Group::AUTO_GROUPS[:trust_level_4]
      expect(Guardian.new.can_recover_topic?(Topic.with_deleted.last)).to eq(false)
    end
  end

  describe "#can_edit_topic?" do
    context "when the topic is a shared draft" do
      let(:tl2_user) { Fabricate(:user, trust_level: TrustLevel[2]) }

      before do
        SiteSetting.shared_drafts_category = category.id
        SiteSetting.shared_drafts_allowed_groups = Group::AUTO_GROUPS[:trust_level_2]
      end

      it "returns false if the topic is a PM" do
        pm_with_draft = Fabricate(:private_message_topic, category: category)
        Fabricate(:shared_draft, topic: pm_with_draft)

        expect(Guardian.new(tl2_user).can_edit_topic?(pm_with_draft)).to eq(false)
      end

      it "returns false if the topic is archived" do
        archived_topic = Fabricate(:topic, archived: true, category: category)
        Fabricate(:shared_draft, topic: archived_topic)

        expect(Guardian.new(tl2_user).can_edit_topic?(archived_topic)).to eq(false)
      end

      it "returns true if a shared draft exists" do
        Fabricate(:shared_draft, topic: topic)

        expect(Guardian.new(tl2_user).can_edit_topic?(topic)).to eq(true)
      end

      it "returns false if the user has a lower trust level" do
        tl1_user = Fabricate(:user, trust_level: TrustLevel[1])
        Fabricate(:shared_draft, topic: topic)

        expect(Guardian.new(tl1_user).can_edit_topic?(topic)).to eq(false)
      end

      it "returns true if the shared_draft is from a different category" do
        topic = Fabricate(:topic, category: Fabricate(:category))
        Fabricate(:shared_draft, topic: topic)

        expect(Guardian.new(tl2_user).can_edit_topic?(topic)).to eq(false)
      end
    end
  end

  describe "#is_in_edit_topic_groups?" do
    it "returns true if the user is in edit_all_topic_groups" do
      group.add(user)
      SiteSetting.edit_all_topic_groups = group.id.to_s

      expect(Guardian.new(user).is_in_edit_topic_groups?).to eq(true)
    end

    it "returns false if the user is not in edit_all_topic_groups" do
      SiteSetting.edit_all_topic_groups = Group::AUTO_GROUPS[:trust_level_4]

      expect(Guardian.new(tl3_user).is_in_edit_topic_groups?).to eq(false)
    end

    it "returns false if the edit_all_topic_groups is empty" do
      SiteSetting.edit_all_topic_groups = nil

      expect(Guardian.new(user).is_in_edit_topic_groups?).to eq(false)
    end
  end

  describe "#can_review_topic?" do
    it "returns false for TL4 users" do
      topic = Fabricate(:topic)

      expect(Guardian.new(tl4_user).can_review_topic?(topic)).to eq(false)
    end
  end

  describe "#can_create_unlisted_topic?" do
    it "returns true for moderators" do
      expect(Guardian.new(moderator).can_create_unlisted_topic?(topic)).to eq(true)
    end

    it "returns true for TL4 users" do
      expect(Guardian.new(tl4_user).can_create_unlisted_topic?(topic)).to eq(true)
    end

    it "returns false for regular users" do
      expect(Guardian.new(user).can_create_unlisted_topic?(topic)).to eq(false)
    end
  end

  describe "#can_see_unlisted_topics?" do
    it "is allowed for staff users" do
      expect(Guardian.new(moderator).can_see_unlisted_topics?).to eq(true)
    end

    it "is allowed for TL4 users" do
      expect(Guardian.new(tl4_user).can_see_unlisted_topics?).to eq(true)
    end

    it "is not allowed for lower level users" do
      expect(Guardian.new(tl3_user).can_see_unlisted_topics?).to eq(false)
    end
  end

  # The test cases here are intentionally kept brief because majority of the cases are already handled by
  # `TopicGuardianCanSeeConsistencyCheck` which we run to ensure that the implementation between `TopicGuardian#can_see_topic_ids`
  # and `TopicGuardian#can_see_topic?` is consistent.
  describe "#can_see_topic_ids" do
    it "returns the topic ids for the topics which a user is allowed to see" do
      expect(
        Guardian.new.can_see_topic_ids(topic_ids: [topic.id, private_message_topic.id]),
      ).to contain_exactly(topic.id)

      expect(
        Guardian.new(user).can_see_topic_ids(topic_ids: [topic.id, private_message_topic.id]),
      ).to contain_exactly(topic.id)

      expect(
        Guardian.new(moderator).can_see_topic_ids(topic_ids: [topic.id, private_message_topic.id]),
      ).to contain_exactly(topic.id)

      expect(
        Guardian.new(admin).can_see_topic_ids(topic_ids: [topic.id, private_message_topic.id]),
      ).to contain_exactly(topic.id, private_message_topic.id)
    end

    it "returns the topic ids for topics which are deleted but user is a category moderator of" do
      SiteSetting.enable_category_group_moderation = true

      Fabricate(:category_moderation_group, category:, group:)
      group.add(user)
      topic.update!(category: category)
      topic.trash!(admin)

      topic2 = Fabricate(:topic)
      user2 = Fabricate(:user)

      expect(
        Guardian.new(user).can_see_topic_ids(topic_ids: [topic.id, topic2.id]),
      ).to contain_exactly(topic.id, topic2.id)

      expect(
        Guardian.new(user2).can_see_topic_ids(topic_ids: [topic.id, topic2.id]),
      ).to contain_exactly(topic2.id)
    end
  end

  describe "#filter_allowed_categories" do
    it "allows admin access to categories without explicit access" do
      guardian = Guardian.new(admin)
      list = Topic.where(id: private_topic.id)
      list = guardian.filter_allowed_categories(list)

      expect(list.count).to eq(1)
    end

    context "when SiteSetting.suppress_secured_categories_from_admin is true" do
      before { SiteSetting.suppress_secured_categories_from_admin = true }

      it "does not allow admin access to categories without explicit access" do
        guardian = Guardian.new(admin)
        list = Topic.where(id: private_topic.id)
        list = guardian.filter_allowed_categories(list)

        expect(list.count).to eq(0)

        expect(guardian.can_see?(private_topic)).to eq(false)
      end
    end
  end
end
