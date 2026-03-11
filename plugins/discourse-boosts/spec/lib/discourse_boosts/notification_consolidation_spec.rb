# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseBoosts::NotificationConsolidation do
  fab!(:post_author, :user)
  fab!(:target_post, :post) { Fabricate(:post, user: post_author) }

  def build_boost_notification(from_user:, post: target_post)
    Fabricate.build(
      :notification,
      user: post_author,
      notification_type: Notification.types[:boost],
      topic: post.topic,
      post_number: post.post_number,
      data: {
        display_username: from_user.username,
        display_name: from_user.name,
        boost_raw: "🎉",
        boost_cooked: "<p>🎉</p>",
        topic_title: post.topic.title,
      }.to_json,
    )
  end

  describe ".boosted_by_multiple_users_plan" do
    fab!(:user_1, :user)
    fab!(:user_2, :user)

    it "replaces the previous notification with a merged one" do
      plan = described_class.boosted_by_multiple_users_plan

      build_boost_notification(from_user: user_1).save!

      plan.consolidate_or_save!(build_boost_notification(from_user: user_2))

      notifications =
        Notification.where(user: post_author, notification_type: Notification.types[:boost])
      expect(notifications.count).to eq(1)

      data = JSON.parse(notifications.first.read_attribute(:data))
      expect(data["display_username"]).to eq(user_2.username)
      expect(data["username2"]).to eq(user_1.username)
      expect(data["count"]).to eq(2)
    end

    it "does not consolidate when no existing notification matches" do
      plan = described_class.boosted_by_multiple_users_plan

      expect(plan.consolidate_or_save!(build_boost_notification(from_user: user_1))).to be_nil
    end
  end

  describe ".consolidated_boosts_plan" do
    fab!(:booster, :user)
    fab!(:posts) { 3.times.map { Fabricate(:post, user: post_author) } }

    it "consolidates once threshold is reached" do
      SiteSetting.notification_consolidation_threshold = 2

      plan = described_class.consolidated_boosts_plan

      posts.each do |p|
        plan.consolidate_or_save!(build_boost_notification(from_user: booster, post: p))
      end

      notifications =
        Notification.where(user: post_author, notification_type: Notification.types[:boost])

      expect(notifications.count).to eq(1)
      expect(notifications.first.data_hash[:consolidated]).to eq(true)
      expect(notifications.first.data_hash[:count]).to eq(3)
    end

    it "saves individually below threshold" do
      SiteSetting.notification_consolidation_threshold = 10

      plan = described_class.consolidated_boosts_plan

      posts.each do |p|
        plan.consolidate_or_save!(build_boost_notification(from_user: booster, post: p))
      end

      expect(
        Notification.where(user: post_author, notification_type: Notification.types[:boost]).count,
      ).to eq(3)
    end
  end
end
