# frozen_string_literal: true

module Jobs
  class ProcessShelvedNotifications < ::Jobs::Scheduled
    every 5.minutes

    def execute(args)
      sql = <<~SQL
        SELECT sn.id FROM shelved_notifications as sn
        INNER JOIN notifications AS notification ON sn.notification_id = notification.id
        INNER JOIN do_not_disturb_timings AS dndt ON notification.user_id = dndt.user_id
        AND dndt.ends_at <= :now
      SQL

      now = Time.zone.now
      shelved_notification_ids = DB.query_single(sql, now: now)
      shelved_notifications = ShelvedNotification.where(id: shelved_notification_ids)
      shelved_notifications.each(&:process)
      shelved_notifications.destroy_all

      DB.exec("DELETE FROM do_not_disturb_timings WHERE ends_at < :now", now: now)
    end
  end
end
