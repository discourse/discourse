module Jobs
  class PurgeExpiredIgnoredUsers < Jobs::Scheduled
    every 1.day

    def execute(args)
      IgnoredUser.where('created_at <= ?', 4.months.ago).delete_all
    end
  end
end
