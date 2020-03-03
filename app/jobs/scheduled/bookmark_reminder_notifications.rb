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

      where_clause = <<-SQL
        reminder_at IS NOT NULL AND reminder_type != :at_desktop
        AND reminder_at <= :now
      SQL
      bookmarks = Bookmark.where(
        where_clause, at_desktop: Bookmark.reminder_types[:at_desktop], now: Time.now.utc
      ).includes(:user).order('reminder_at ASC')

      bookmarks.limit(MAX_REMINDER_NOTIFICATIONS_PER_RUN).each do |bookmark|
        BookmarkReminderNotificationHandler.send_notification(bookmark)
      end

      remaining_reminders = bookmarks.count
      if remaining_reminders.positive?
        Rails.logger.warn("Too many bookmarks to send reminders for. #{remaining_reminders} additional bookmark reminder(s) will be sent in the next run.")
      end
    end
  end
end
