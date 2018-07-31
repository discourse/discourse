module Jobs

  class CleanUpEmailLogs < Jobs::Scheduled
    every 1.day

    def execute(args)
      return if SiteSetting.delete_email_logs_after_days <= 0

      threshold = SiteSetting.delete_email_logs_after_days.days.ago

      EmailLog.where("created_at < ?", threshold).delete_all
      SkippedEmailLog.where("created_at < ?", threshold).delete_all
    end

  end

end
