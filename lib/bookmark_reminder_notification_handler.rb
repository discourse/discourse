# frozen_string_literal: true

class BookmarkReminderNotificationHandler
  def self.send_notification(bookmark)
    return if bookmark.blank?
    Bookmark.transaction do
      if bookmark.post.blank? || bookmark.post.deleted_at.present?
        return clear_reminder(bookmark)
      end

      create_notification(bookmark)

      if bookmark.delete_when_reminder_sent?
        return bookmark.destroy
      end

      clear_reminder(bookmark)
    end
  end

  def self.clear_reminder(bookmark)
    Rails.logger.debug(
      "Clearing bookmark reminder for bookmark_id #{bookmark.id}. reminder info: #{bookmark.reminder_at} | #{Bookmark.reminder_types[bookmark.reminder_type]}"
    )

    bookmark.update(
      reminder_at: nil,
      reminder_type: nil,
      reminder_last_sent_at: Time.zone.now,
      reminder_set_at: nil
    )
  end

  def self.create_notification(bookmark)
    user = bookmark.user
    user.notifications.create!(
      notification_type: Notification.types[:bookmark_reminder],
      topic_id: bookmark.topic_id,
      post_number: bookmark.post.post_number,
      data: {
        topic_title: bookmark.topic.title,
        display_username: user.username,
        bookmark_name: bookmark.name
      }.to_json
    )
  end
end
