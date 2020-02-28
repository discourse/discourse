# frozen_string_literal: true

module Jobs
  class BookmarkReminder < ::Jobs::Base
    def execute(args)
      bookmark = Bookmark.find_by(id: args[:bookmark_id])

      Bookmark.transaction do
        if bookmark.blank? || bookmark.post.blank?
          Rails.logger.warn("The bookmark or post for bookmark_id #{args[:bookmark_id]} has been deleted, clearing reminder.")
          return clear_reminder(bookmark)
        end

        send_notification(bookmark)
        clear_reminder(bookmark)
      end
    end

    def clear_reminder(bookmark)
      return if bookmark.blank?
      Rails.logger.debug(
        "Clearing bookmark reminder for bookmark_id #{bookmark.id}. reminder info: #{bookmark.reminder_at} | #{Bookmark.reminder_types[bookmark.reminder_type]}"
      )

      bookmark.update(
        reminder_at: nil,
        reminder_type: nil,
        reminder_last_sent_at: Time.now.utc
      )
    end

    def send_notification(bookmark)
      user = bookmark.user
      user.notifications.create!(
        notification_type: Notification.types[:bookmark_reminder],
        topic_id: bookmark.topic_id,
        post_number: bookmark.post.post_number,
        data: { topic_title: bookmark.topic.title, display_username: user.username }.to_json
      )
    end
  end
end
