# frozen_string_literal: true

module Jobs

  # Runs periodically to send out bookmark reminders, capped at 300 at a time.
  # Any leftovers will be caught in the next run, because the reminder_at column
  # is set to NULL once a reminder has been sent.
  class BookmarkReminderNotifications < ::Jobs::Scheduled
    JOB_RUN_NUMBER_KEY ||= 'jobs_bookmark_reminder_notifications_job_run_num'.freeze
    AT_DESKTOP_CONSISTENCY_RUN_NUMBER ||= 6

    every 5.minutes

    def self.max_reminder_notifications_per_run
      @@max_reminder_notifications_per_run ||= 3
      @@max_reminder_notifications_per_run
    end

    def self.max_reminder_notifications_per_run=(max)
      @@max_reminder_notifications_per_run = max
    end

    def execute(args = nil)
      return if !SiteSetting.enable_bookmarks_with_reminders?

      bookmarks = Bookmark.pending_reminders
        .where.not(reminder_type: Bookmark.reminder_types[:at_desktop])
        .includes(:user).order('reminder_at ASC')

      bookmarks.limit(BookmarkReminderNotifications.max_reminder_notifications_per_run).each do |bookmark|
        BookmarkReminderNotificationHandler.send_notification(bookmark)
      end

      # we only want to ensure the desktop consistency every X runs of this job
      # (every 30 mins in this case) so we don't bother redis too much, and the
      # at desktop consistency problem should not really happen unless people
      # are setting the "at desktop" reminder, going out for milk, and never coming
      # back
      current_job_run_number = Discourse.redis.get(JOB_RUN_NUMBER_KEY).to_i
      if current_job_run_number == AT_DESKTOP_CONSISTENCY_RUN_NUMBER
        ensure_at_desktop_consistency
      end

      increment_job_run_number(current_job_run_number)
    end

    def increment_job_run_number(current_job_run_number)
      if current_job_run_number.zero? || current_job_run_number == AT_DESKTOP_CONSISTENCY_RUN_NUMBER
        new_job_run_number = 1
      else
        new_job_run_number = current_job_run_number + 1
      end
      Discourse.redis.set(JOB_RUN_NUMBER_KEY, new_job_run_number)
    end

    def ensure_at_desktop_consistency
      pending_at_desktop_bookmark_reminders = \
        Bookmark.includes(:user)
          .references(:user)
          .pending_at_desktop_reminders
          .where('users.last_seen_at >= :one_day_ago', one_day_ago: 1.day.ago.utc)

      return if pending_at_desktop_bookmark_reminders.count.zero?

      unique_users = pending_at_desktop_bookmark_reminders.map(&:user).uniq.map { |u| [u.id, u] }.flatten
      unique_users = Hash[*unique_users]
      pending_reminders_for_redis_check = unique_users.keys.map do |user_id|
        "#{BookmarkReminderNotificationHandler::PENDING_AT_DESKTOP_KEY_PREFIX}#{user_id}"
      end

      Discourse.redis.mget(pending_reminders_for_redis_check).each.with_index do |value, idx|
        next if value.present?
        user_id = pending_reminders_for_redis_check[idx][/\d+/].to_i
        user = unique_users[user_id]

        user_pending_bookmark_reminders = pending_at_desktop_bookmark_reminders.select do |bookmark|
          bookmark.user == user
        end

        user_expired_bookmark_reminders = user_pending_bookmark_reminders.select do |bookmark|
          bookmark.reminder_set_at <= expiry_limit_datetime
        end

        next if user_pending_bookmark_reminders.length == user_expired_bookmark_reminders.length

        # only tell the cache-gods that this user has pending "at desktop" reminders
        # if they haven't let them all expire before coming back to their desktop
        #
        # the next time they visit the desktop the reminders will be cleared out once
        # the notifications are sent
        BookmarkReminderNotificationHandler.cache_pending_at_desktop_reminder(user)
      end

      clear_expired_at_desktop_reminders
    end

    def clear_expired_at_desktop_reminders
      Bookmark
        .pending_at_desktop_reminders
        .where('reminder_set_at <= :expiry_limit_datetime', expiry_limit_datetime: expiry_limit_datetime)
        .update_all(
          reminder_set_at: nil, reminder_type: nil
        )
    end

    def expiry_limit_datetime
      BookmarkReminderNotificationHandler::PENDING_AT_DESKTOP_EXPIRY_DAYS.days.ago.utc
    end
  end
end
