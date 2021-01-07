# frozen_string_literal: true

module Jobs
  class ProcessShelvedNotifications < ::Jobs::Scheduled
    every 5.minutes

    def execute(args)
      sql = <<~SQL
        SELECT n.id FROM notifications AS n
        INNER JOIN do_not_disturb_timings AS dndt ON n.user_id = dndt.user_id
        WHERE n.processed = false
        AND dndt.ends_at <= :now
      SQL

      now = Time.zone.now
      notification_ids = DB.query_single(sql, now: now)

      Notification.where(id: notification_ids).each do |notification|
        begin
          NotificationEmailer.process_notification(notification, no_delay: true)
        rescue
          Rails.logger.warn("Failed to process notification with ID #{notification.id}")
        end
      end

      DB.exec("DELETE FROM do_not_disturb_timings WHERE ends_at < :now", now: now)
    end
  end
end
