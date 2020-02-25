# frozen_string_literal: true

module Jobs
  class CleanUpPostReplyKeys < ::Jobs::Scheduled
    every 1.day

    def execute(_)
      return if SiteSetting.disallow_reply_by_email_after_days <= 0

      PostReplyKey.where(
        "created_at < ?",
        SiteSetting.disallow_reply_by_email_after_days.days.ago
      ).delete_all
    end
  end
end
