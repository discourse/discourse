# frozen_string_literal: true

module Jobs

  # Runs periodically to send out bookmark reminders, capped at 300 at a time.
  # Any leftovers will be caught in the next run, because the reminder_at column
  # is set to NULL once a reminder has been sent.
  class BookmarkReminderNotifications < ::Jobs::Scheduled
    MAX_REMINDER_NOTIFICATIONS_PER_RUN = 300

    every 5.minutes

    def execute(args = nil)
      return if !SiteSetting.enable_bookmarks_with_reminders?

      bookmarks = Bookmark.pending_reminders
        .where.not(reminder_type: Bookmark.reminder_types[:at_desktop])
        .includes(:user).order('reminder_at ASC')

      bookmarks.limit(MAX_REMINDER_NOTIFICATIONS_PER_RUN).each do |bookmark|
        BookmarkReminderNotificationHandler.send_notification(bookmark)
      end
    end
  end
end
