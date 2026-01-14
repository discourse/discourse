# frozen_string_literal: true

RSpec.describe StaffActionLogGuardian do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)

  describe "#can_see_staff_action_log?" do
    it "returns true for admins regardless of action type" do
      admin_only_log =
        UserHistory.create!(action: UserHistory.actions[:change_site_setting], subject: "title")
      expect(Guardian.new(admin).can_see_staff_action_log?(admin_only_log)).to eq(true)
    end

    it "returns false for non-staff users" do
      log = UserHistory.create!(action: UserHistory.actions[:suspend_user])
      expect(Guardian.new(user).can_see_staff_action_log?(log)).to eq(false)
    end

    it "returns true for moderators when action is in moderator_visible_actions" do
      log = UserHistory.create!(action: UserHistory.actions[:suspend_user])
      expect(Guardian.new(moderator).can_see_staff_action_log?(log)).to eq(true)
    end

    it "returns false for moderators when action is admin-only" do
      log = UserHistory.create!(action: UserHistory.actions[:change_site_setting], subject: "title")
      expect(Guardian.new(moderator).can_see_staff_action_log?(log)).to eq(false)
    end

    it "respects site setting gates for moderators" do
      SiteSetting.moderators_manage_categories = true
      category = Fabricate(:category)
      log =
        UserHistory.create!(action: UserHistory.actions[:create_category], category_id: category.id)
      expect(Guardian.new(moderator).can_see_staff_action_log?(log)).to eq(true)

      SiteSetting.moderators_manage_categories = false
      expect(Guardian.new(moderator).can_see_staff_action_log?(log)).to eq(false)
    end
  end

  describe "#can_see_staff_action_log_content?" do
    it "returns true for admins regardless of content" do
      pm = Fabricate(:private_message_topic)
      log = UserHistory.create!(action: UserHistory.actions[:delete_topic], topic_id: pm.id)
      expect(Guardian.new(admin).can_see_staff_action_log_content?(log)).to eq(true)
    end

    it "returns true for moderators when topic is public" do
      topic = Fabricate(:topic)
      log = UserHistory.create!(action: UserHistory.actions[:delete_topic], topic_id: topic.id)
      expect(Guardian.new(moderator).can_see_staff_action_log_content?(log)).to eq(true)
    end

    it "returns false for moderators when topic is a PM they cannot see" do
      pm = Fabricate(:private_message_topic)
      log = UserHistory.create!(action: UserHistory.actions[:delete_topic], topic_id: pm.id)
      expect(Guardian.new(moderator).can_see_staff_action_log_content?(log)).to eq(false)
    end

    it "returns false for moderators when post is in a topic they cannot see" do
      pm = Fabricate(:private_message_topic)
      post = Fabricate(:post, topic: pm)
      log = UserHistory.create!(action: UserHistory.actions[:post_edit], post_id: post.id)
      expect(Guardian.new(moderator).can_see_staff_action_log_content?(log)).to eq(false)
    end

    it "returns false for moderators when category is restricted" do
      group = Fabricate(:group)
      category = Fabricate(:private_category, group:)
      log =
        UserHistory.create!(
          action: UserHistory.actions[:change_category_settings],
          category_id: category.id,
        )
      expect(Guardian.new(moderator).can_see_staff_action_log_content?(log)).to eq(false)
    end

    it "returns true for moderators when category is public" do
      category = Fabricate(:category)
      log =
        UserHistory.create!(
          action: UserHistory.actions[:change_category_settings],
          category_id: category.id,
        )
      expect(Guardian.new(moderator).can_see_staff_action_log_content?(log)).to eq(true)
    end

    it "returns false when referenced topic is deleted" do
      topic = Fabricate(:topic)
      log = UserHistory.create!(action: UserHistory.actions[:delete_topic], topic_id: topic.id)
      topic.destroy!
      expect(Guardian.new(moderator).can_see_staff_action_log_content?(log)).to eq(false)
    end

    it "returns false when referenced post is deleted" do
      post = Fabricate(:post)
      log = UserHistory.create!(action: UserHistory.actions[:post_edit], post_id: post.id)
      post.destroy!
      expect(Guardian.new(moderator).can_see_staff_action_log_content?(log)).to eq(false)
    end

    it "returns false when referenced category is deleted" do
      category = Fabricate(:category)
      log =
        UserHistory.create!(
          action: UserHistory.actions[:change_category_settings],
          category_id: category.id,
        )
      category.destroy!
      expect(Guardian.new(moderator).can_see_staff_action_log_content?(log)).to eq(false)
    end
  end
end
