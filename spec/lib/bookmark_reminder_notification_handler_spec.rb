# frozen_string_literal: true

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

    context "when the topic is deleted" do
      before do
        bookmark.topic.trash!
        bookmark.reload
      end

      it "does not send a notification and updates last notification attempt time" do
        expect { subject.send_notification(bookmark) }.not_to change { Notification.count }
        expect(bookmark.reload.reminder_last_sent_at).not_to be_blank
      end
    end

    context "when the post is deleted" do
      before do
        bookmark.post.trash!
        bookmark.reload
      end

      it "does not send a notification and updates last notification attempt time" do
        expect { subject.send_notification(bookmark) }.not_to change { Notification.count }
        expect(bookmark.reload.reminder_last_sent_at).not_to be_blank
      end
    end

    context "when the auto_delete_preference is when_reminder_sent" do
      before do
        TopicUser.create!(topic: bookmark.topic, user: user, bookmarked: true)
        bookmark.update(auto_delete_preference: Bookmark.auto_delete_preferences[:when_reminder_sent])
      end

      it "deletes the bookmark after the reminder gets sent" do
        subject.send_notification(bookmark)
        expect(Bookmark.find_by(id: bookmark.id)).to eq(nil)
      end

      it "changes the TopicUser bookmarked column to false" do
        subject.send_notification(bookmark)
        expect(TopicUser.find_by(topic: bookmark.topic, user: user).bookmarked).to eq(false)
      end

      context "if there are still other bookmarks in the topic" do
        before do
          Fabricate(:bookmark, post: Fabricate(:post, topic: bookmark.topic), user: user)
        end

        it "does not change the TopicUser bookmarked column to false" do
          subject.send_notification(bookmark)
          expect(TopicUser.find_by(topic: bookmark.topic, user: user).bookmarked).to eq(true)
        end
      end
    end

    context "when the auto_delete_preference is clear_reminder" do
      before do
        TopicUser.create!(topic: bookmark.topic, user: user, bookmarked: true)
        bookmark.update(auto_delete_preference: Bookmark.auto_delete_preferences[:clear_reminder])
      end

      it "resets reminder_at after the reminder gets sent" do
        subject.send_notification(bookmark)
        expect(Bookmark.find_by(id: bookmark.id).reminder_at).to eq(nil)
      end
    end

    context "when the post has been deleted" do
      it "does not send a notification" do
        bookmark.post.trash!
        bookmark.reload
        expect { subject.send_notification(bookmark) }.not_to change { Notification.count }
        expect(bookmark.reload.reminder_last_sent_at).not_to be_blank
      end
    end
  end
end
