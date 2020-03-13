# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BookmarkReminderNotificationHandler do
  subject { described_class }

  fab!(:user) { Fabricate(:user) }

  before do
    SiteSetting.enable_bookmarks_with_reminders = true
    Discourse.redis.flushall
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

    context "when the post has been deleted" do
      it "clears the reminder and does not send a notification" do
        bookmark.post.trash!
        bookmark.reload
        subject.send_notification(bookmark)
        expect(bookmark.reload.no_reminder?).to eq(true)
      end
    end
  end

  describe "#send_at_desktop_reminder" do
    fab!(:reminder) do
      Fabricate(
        :bookmark,
        user: user,
        reminder_type: Bookmark.reminder_types[:at_desktop],
        reminder_at: nil,
        reminder_set_at: Time.zone.now
      )
    end
    let(:user_agent) { "Mozilla/5.0 (Windows NT 6.1; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.90 Safari/537.36" }

    context "when there are pending bookmark at desktop reminders" do
      before do
        described_class.cache_pending_at_desktop_reminder(user)
      end

      context "when the user agent is for mobile" do
        let(:user_agent) { "Mozilla/5.0 (iPhone; CPU iPhone OS 9_1 like Mac OS X) AppleWebKit/601.1.46 (KHTML, like Gecko) Version/9.0 Mobile/13B143 Safari/601.1" }
        it "does not attempt to send any reminders" do
          DistributedMutex.expects(:synchronize).never
          send_reminder
        end
      end

      context "when the user agent is for desktop" do
        let(:user_agent) { "Mozilla/5.0 (Windows NT 6.1; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.90 Safari/537.36" }

        it "deletes the key in redis" do
          send_reminder
          expect(described_class.user_has_pending_at_desktop_reminders?(user)).to eq(false)
        end

        it "sends a notification to the user and clears the reminder_at" do
          send_reminder
          expect(Notification.where(user: user, notification_type: Notification.types[:bookmark_reminder]).count).to eq(1)
          expect(reminder.reload.reminder_type).to eq(nil)
          expect(reminder.reload.reminder_last_sent_at).not_to eq(nil)
          expect(reminder.reload.reminder_set_at).to eq(nil)
        end
      end
    end

    context "when there are no pending bookmark at desktop reminders" do
      it "does nothing" do
        DistributedMutex.expects(:synchronize).never
        send_reminder
      end
    end

    context "when enable bookmarks with reminders is disabled" do
      before do
        SiteSetting.enable_bookmarks_with_reminders = false
      end

      it "does nothing" do
        BrowserDetection.expects(:device).never
        send_reminder
      end
    end

    def send_reminder
      subject.send_at_desktop_reminder(user: user, request_user_agent: user_agent)
    end
  end

end
