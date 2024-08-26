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
        bookmark.clear_reminder!
      else
        bookmark.registered_bookmarkable.send_reminder_notification(bookmark)

        if bookmark.auto_delete_when_reminder_sent?
          BookmarkManager.new(bookmark.user).destroy(bookmark.id)
        end

        bookmark.clear_reminder!
      end
    end
  end
end
