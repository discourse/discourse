# frozen_string_literal: true

RSpec.describe Notifications::ConsolidationPlanner do
  subject(:planner) { described_class.new }

  describe "#consolidate_or_save!" do
    let(:threshold) { 1 }
    fab!(:user)
    let(:like_user) { "user1" }
    let(:link_user) { "user2" }
    let(:like_notification) do
      Fabricate.build(
        :notification,
        user: user,
        notification_type: Notification.types[:liked],
        data: { display_username: like_user }.to_json,
      )
    end
    let(:link_notification) do
      Fabricate.build(
        :notification,
        user: user,
        notification_type: Notification.types[:linked],
        data: { display_username: link_user }.to_json,
      )
    end

    before { SiteSetting.notification_consolidation_threshold = threshold }

    it "does nothing when it hasn't passed the consolidation threshold yet for likes" do
      saved_like = planner.consolidate_or_save!(like_notification)

      expect(saved_like.id).to be_present
      expect(saved_like.notification_type).to eq(Notification.types[:liked])
    end

    it "does nothing when it hasn't passed the consolidation threshold yet for links" do
      saved_link = planner.consolidate_or_save!(link_notification)

      expect(saved_link.id).to be_present
      expect(saved_link.notification_type).to eq(Notification.types[:linked])
    end

    it "consolidates multiple like notifications into a new one" do
      first_notification =
        Fabricate(
          :notification,
          user: user,
          notification_type: Notification.types[:liked],
          data: { display_username: like_user }.to_json,
        )
      consolidated_like = planner.consolidate_or_save!(like_notification)

      expect(consolidated_like.id).not_to eq(first_notification.id)
      expect(consolidated_like.notification_type).to eq(Notification.types[:liked_consolidated])
      data = JSON.parse(consolidated_like.data)
      expect(data["count"]).to eq(threshold + 1)
    end

    it "consolidates multiple link notifications into a new one" do
      first_notification =
        Fabricate(
          :notification,
          user: user,
          notification_type: Notification.types[:linked],
          data: { display_username: link_user }.to_json,
        )
      consolidated_link = planner.consolidate_or_save!(link_notification)

      expect(consolidated_link.id).not_to eq(first_notification.id)
      expect(consolidated_link.notification_type).to eq(Notification.types[:linked_consolidated])
      data = JSON.parse(consolidated_link.data)
      expect(data["count"]).to eq(threshold + 1)
    end

    it "updates the like notification if we already consolidated it" do
      count = 5
      Fabricate(
        :notification,
        user: user,
        notification_type: Notification.types[:liked_consolidated],
        data: { count: count, display_username: like_user }.to_json,
      )
      updated = planner.consolidate_or_save!(like_notification)

      expect { like_notification.reload }.to raise_error(ActiveRecord::RecordNotFound)
      data = JSON.parse(updated.data)
      expect(data["count"]).to eq(count + 1)
    end

    it "updates the link notification if we already consolidated it" do
      count = 5
      Fabricate(
        :notification,
        user: user,
        notification_type: Notification.types[:linked_consolidated],
        data: { count: count, display_username: link_user }.to_json,
      )
      updated = planner.consolidate_or_save!(link_notification)

      expect { link_notification.reload }.to raise_error(ActiveRecord::RecordNotFound)
      data = JSON.parse(updated.data)
      expect(data["count"]).to eq(count + 1)
    end
  end
end
