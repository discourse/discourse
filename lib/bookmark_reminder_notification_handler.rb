# frozen_string_literal: true

class BookmarkReminderNotificationHandler
  attr_reader :bookmark

  def initialize(bookmark)
    @bookmark = bookmark
  end

  def send_notification
    return if bookmark.blank?
    Bookmark.transaction do
      # TODO (martin) [POLYBOOK] Can probably change this to call the
      # can_send_reminder? on the registered bookmarkable directly instead
      # of having can_send_reminder?
      if !can_send_reminder?
        clear_reminder
      else
        create_notification

        if bookmark.auto_delete_when_reminder_sent?
          BookmarkManager.new(bookmark.user).destroy(bookmark.id)
        end

        clear_reminder
      end
    end
  end

  private

  def clear_reminder
    Rails.logger.debug(
      "Clearing bookmark reminder for bookmark_id #{bookmark.id}. reminder at: #{bookmark.reminder_at}"
    )

    if bookmark.auto_clear_reminder_when_reminder_sent?
      bookmark.reminder_at = nil
    end

    bookmark.clear_reminder!
  end

  def can_send_reminder?
    if SiteSetting.use_polymorphic_bookmarks
      bookmark.registered_bookmarkable.can_send_reminder?(bookmark)
    else
      bookmark.post.present? && bookmark.topic.present?
    end
  end

  def create_notification
    if SiteSetting.use_polymorphic_bookmarks
      bookmark.registered_bookmarkable.send_reminder_notification(bookmark)
    else
      bookmark.user.notifications.create!(
        notification_type: Notification.types[:bookmark_reminder],
        topic_id: bookmark.topic_id,
        post_number: bookmark.post.post_number,
        data: {
          topic_title: bookmark.topic.title,
          display_username: bookmark.user.username,
          bookmark_name: bookmark.name
        }.to_json
      )
    end
  end
end
