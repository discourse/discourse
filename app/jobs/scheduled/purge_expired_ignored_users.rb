# frozen_string_literal: true

module Jobs
  class PurgeExpiredIgnoredUsers < ::Jobs::Scheduled
    every 1.day

    def execute(args)
      IgnoredUser.where("created_at <= ? OR expiring_at <= ?", 4.months.ago, Time.zone.now).delete_all
    end
  end
end
