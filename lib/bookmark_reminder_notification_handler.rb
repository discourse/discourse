# frozen_string_literal: true

class BookmarkReminderNotificationHandler
  attr_reader :bookmark

  def initialize(bookmark)
    @bookmark = bookmark
  end

  def send_notification
    return if bookmark.blank?
    Bookmark.transaction do
      if !bookmark.registered_bookmarkable.can_send_reminder?(bookmark)
        clear_reminder
      else
        bookmark.registered_bookmarkable.send_reminder_notification(bookmark)

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
      "Clearing bookmark reminder for bookmark_id #{bookmark.id}. reminder at: #{bookmark.reminder_at}",
    )

    bookmark.reminder_at = nil if bookmark.auto_clear_reminder_when_reminder_sent?

    bookmark.clear_reminder!
  end
end
