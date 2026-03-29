# frozen_string_literal: true

require "rails_helper"

RSpec.describe Post, type: :model do
  before { SiteSetting.discourse_boosts_enabled = true }

  it do
    is_expected.to have_many(:boosts)
      .class_name("DiscourseBoosts::Boost")
      .dependent(:delete_all)
      .inverse_of(:post)
  end

  describe "#delete_boost_notifications" do
    fab!(:post)

    it "deletes boost notifications for the post author when the post is destroyed" do
      notification =
        Fabricate(
          :notification,
          user: post.user,
          topic: post.topic,
          post_number: post.post_number,
          notification_type: Notification.types[:boost],
        )

      post.destroy!

      expect(Notification.exists?(notification.id)).to eq(false)
    end

    it "does not delete boost notifications for other posts" do
      other_post = Fabricate(:post)
      notification =
        Fabricate(
          :notification,
          user: other_post.user,
          topic: other_post.topic,
          post_number: other_post.post_number,
          notification_type: Notification.types[:boost],
        )

      post.destroy!

      expect(Notification.exists?(notification.id)).to eq(true)
    end
  end
end
