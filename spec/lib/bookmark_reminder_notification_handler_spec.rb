# frozen_string_literal: true

RSpec.describe BookmarkReminderNotificationHandler do
  fab!(:user)

  before { Discourse.redis.flushdb }

  describe "#send_notification" do
    subject(:send_notification) { handler.send_notification }

    let(:handler) { described_class.new(bookmark) }
    let!(:bookmark) do
      Fabricate(:bookmark_next_business_day_reminder, user: user, bookmarkable: Fabricate(:post))
    end

    it "creates a bookmark reminder notification with the correct details" do
      send_notification
      notif = bookmark.user.notifications.last
      expect(notif.notification_type).to eq(Notification.types[:bookmark_reminder])
      expect(notif.topic_id).to eq(bookmark.bookmarkable.topic_id)
      expect(notif.post_number).to eq(bookmark.bookmarkable.post_number)
      data = JSON.parse(notif.data)
      expect(data["title"]).to eq(bookmark.bookmarkable.topic.title)
      expect(data["display_username"]).to eq(bookmark.user.username)
      expect(data["bookmark_name"]).to eq(bookmark.name)
      expect(data["bookmarkable_url"]).to eq(bookmark.bookmarkable.url)
    end

    context "when the bookmarkable is deleted" do
      before do
        bookmark.bookmarkable.trash!
        bookmark.reload
      end

      it "does not send a notification and updates last notification attempt time" do
        expect { send_notification }.not_to change { Notification.count }
        expect(bookmark.reload.reminder_last_sent_at).not_to be_blank
      end
    end

    context "when the auto_delete_preference is when_reminder_sent" do
      before do
        TopicUser.create!(topic: bookmark.bookmarkable.topic, user: user, bookmarked: true)
        bookmark.update(
          auto_delete_preference: Bookmark.auto_delete_preferences[:when_reminder_sent],
        )
      end

      it "deletes the bookmark after the reminder gets sent" do
        send_notification
        expect(Bookmark.find_by(id: bookmark.id)).to eq(nil)
      end

      it "changes the TopicUser bookmarked column to false" do
        send_notification
        expect(TopicUser.find_by(topic: bookmark.bookmarkable.topic, user: user).bookmarked).to eq(
          false,
        )
      end

      context "if there are still other bookmarks in the topic" do
        before do
          Fabricate(
            :bookmark,
            bookmarkable: Fabricate(:post, topic: bookmark.bookmarkable.topic),
            user: user,
          )
        end

        it "does not change the TopicUser bookmarked column to false" do
          send_notification
          expect(
            TopicUser.find_by(topic: bookmark.bookmarkable.topic, user: user).bookmarked,
          ).to eq(true)
        end
      end
    end

    context "when the auto_delete_preference is clear_reminder" do
      before do
        TopicUser.create!(topic: bookmark.bookmarkable.topic, user: user, bookmarked: true)
        bookmark.update(auto_delete_preference: Bookmark.auto_delete_preferences[:clear_reminder])
      end

      it "resets reminder_at after the reminder gets sent" do
        send_notification
        expect(Bookmark.find_by(id: bookmark.id).reminder_at).to eq(nil)
      end
    end

    context "when the auto_delete_preference is never" do
      before do
        TopicUser.create!(topic: bookmark.bookmarkable.topic, user: user, bookmarked: true)
        bookmark.update(auto_delete_preference: Bookmark.auto_delete_preferences[:never])
      end

      it "does not reset reminder_at after the reminder gets sent" do
        send_notification
        expect(Bookmark.find_by(id: bookmark.id).reminder_at).not_to eq(nil)
      end
    end
  end
end
