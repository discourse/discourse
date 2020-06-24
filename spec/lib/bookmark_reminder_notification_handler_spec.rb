# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BookmarkReminderNotificationHandler do
  subject { described_class }

  fab!(:user) { Fabricate(:user) }

  before do
    Discourse.redis.flushdb
  end

  describe "#send_notification" do
    fab!(:bookmark) do
      Fabricate(:bookmark_next_business_day_reminder, user: user)
    end

    it "creates a bookmark reminder notification with the correct details" do
      subject.send_notification(bookmark)
      notif = bookmark.user.notifications.last
      expect(notif.notification_type).to eq(Notification.types[:bookmark_reminder])
      expect(notif.topic_id).to eq(bookmark.topic_id)
      expect(notif.post_number).to eq(bookmark.post.post_number)
      data = JSON.parse(notif.data)
      expect(data["topic_title"]).to eq(bookmark.topic.title)
      expect(data["display_username"]).to eq(bookmark.user.username)
      expect(data["bookmark_name"]).to eq(bookmark.name)
    end

    it "clears the reminder" do
      subject.send_notification(bookmark)
      bookmark.reload
      expect(bookmark.reload.no_reminder?).to eq(true)
    end

    context "when the delete_when_reminder_sent boolean is true " do
      it "deletes the bookmark after the reminder gets sent" do
        bookmark.update(delete_when_reminder_sent: true)
        subject.send_notification(bookmark)
        expect(Bookmark.find_by(id: bookmark.id)).to eq(nil)
      end
    end

    context "when the post has been deleted" do
      it "clears the reminder and does not send a notification" do
        bookmark.post.trash!
        bookmark.reload
        subject.send_notification(bookmark)
        expect(bookmark.reload.no_reminder?).to eq(true)
      end
    end
  end
end
