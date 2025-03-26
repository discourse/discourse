# frozen_string_literal: true

module Jobs
  class PurgeOldNotifications < ::Jobs::Scheduled
    every 1.week

    def execute(args)
      Notification.purge_old!
    end
  end
end
