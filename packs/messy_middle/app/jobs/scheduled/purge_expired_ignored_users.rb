# frozen_string_literal: true

module Jobs
  class PurgeExpiredIgnoredUsers < ::Jobs::Scheduled
    every 1.day

    def execute(args)
      IgnoredUser.where("expiring_at <= ?", Time.zone.now).delete_all
    end
  end
end
