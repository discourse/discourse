# frozen_string_literal: true

module Jobs
  class CleanupImapSyncLog < ::Jobs::Scheduled
    every 1.day

    def execute(args)
      ImapSyncLog.where("created_at < ?", ImapSyncLog::RETAIN_LOGS_DAYS.days.ago).delete_all
    end
  end
end
