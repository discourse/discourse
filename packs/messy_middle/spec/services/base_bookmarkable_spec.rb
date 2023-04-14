# frozen_string_literal: true

RSpec.describe BaseBookmarkable do
  fab!(:bookmark) { Fabricate(:bookmark, bookmarkable: Fabricate(:post)) }

  describe "#send_reminder_notification" do
    it "raises an error if the data, data.bookmarkable_url, or data.title values are missing from notification_data" do
      expect { BaseBookmarkable.send_reminder_notification(bookmark, {}) }.to raise_error(
        Discourse::InvalidParameters,
      )
      expect { BaseBookmarkable.send_reminder_notification(bookmark, { data: {} }) }.to raise_error(
        Discourse::InvalidParameters,
      )
      expect {
        BaseBookmarkable.send_reminder_notification(
          bookmark,
          { data: { title: "test", bookmarkable_url: "test" } },
        )
      }.not_to raise_error
    end

    it "creates a Notification with the required data from the bookmark" do
      BaseBookmarkable.send_reminder_notification(
        bookmark,
        {
          topic_id: bookmark.bookmarkable.topic_id,
          post_number: bookmark.bookmarkable.post_number,
          data: {
            title: bookmark.bookmarkable.topic.title,
            bookmarkable_url: bookmark.bookmarkable.url,
          },
        },
      )
      notif = bookmark.user.notifications.last
      expect(notif.notification_type).to eq(Notification.types[:bookmark_reminder])
      expect(notif.topic_id).to eq(bookmark.bookmarkable.topic_id)
      expect(notif.post_number).to eq(bookmark.bookmarkable.post_number)
      expect(notif.data).to eq(
        {
          title: bookmark.bookmarkable.topic.title,
          bookmarkable_url: bookmark.bookmarkable.url,
          display_username: bookmark.user.username,
          bookmark_name: bookmark.name,
          bookmark_id: bookmark.id,
        }.to_json,
      )
    end

    it "does not allow the consumer to override display_username, bookmark_name, or bookmark_id" do
      BaseBookmarkable.send_reminder_notification(
        bookmark,
        {
          topic_id: bookmark.bookmarkable.topic_id,
          post_number: bookmark.bookmarkable.post_number,
          data: {
            title: bookmark.bookmarkable.topic.title,
            bookmarkable_url: bookmark.bookmarkable.url,
            display_username: "bad username",
            bookmark_name: "bad name",
            bookmark_id: -89_854,
          },
        },
      )

      notif = bookmark.user.notifications.last
      data = JSON.parse(notif[:data])
      expect(data[:display_username]).not_to eq("bad username")
      expect(data[:name]).not_to eq("bad name")
      expect(data[:bookmark_id]).not_to eq(-89_854)
    end
  end
end
