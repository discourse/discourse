# frozen_string_literal: true

module Jobs
  # Runs periodically to send out bookmark reminders, capped at 300 at a time.
  # Any leftovers will be caught in the next run, because the reminder_at column
  # is set to NULL once a reminder has been sent.
  class BookmarkReminderNotifications < ::Jobs::Scheduled
    every 5.minutes

    def self.max_reminder_notifications_per_run
      @@max_reminder_notifications_per_run ||= 300
      @@max_reminder_notifications_per_run
    end

    def self.max_reminder_notifications_per_run=(max)
      @@max_reminder_notifications_per_run = max
    end

    def execute(args = nil)
      bookmarks = Bookmark.pending_reminders.includes(:user).order("reminder_at ASC")
      bookmarks
        .limit(BookmarkReminderNotifications.max_reminder_notifications_per_run)
        .each { |bookmark| BookmarkReminderNotificationHandler.new(bookmark).send_notification }
    end
  end
end
