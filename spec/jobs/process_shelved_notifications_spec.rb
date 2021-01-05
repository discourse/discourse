# frozen_string_literal: true

require "rails_helper"

describe Jobs::ProcessShelvedNotifications do
  fab!(:user) { Fabricate(:user) }
  let(:post) { Fabricate(:post) }
  Notification.create!(read: false, user_id: user.id, topic_id: post.topic_id, post_number: post.post_number, data: '[]', notification_type: type, created_at: 0.days.from_now)

  it "automatically marks the notification as high priority if it is a high priority type" do
    notif = Notification.create(user: user, notification_type: Notification.types[:bookmark_reminder], data: {})
  end
end
