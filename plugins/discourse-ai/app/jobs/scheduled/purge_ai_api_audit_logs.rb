# frozen_string_literal: true

module Jobs
  class PurgeAiApiAuditLogs < ::Jobs::Scheduled
    every 1.day

    BATCH_SIZE = 1_000

    def execute(_args)
      summary_retention_days = SiteSetting.ai_audit_logs_purge_after_days.to_i
      detailed_retention_days = SiteSetting.ai_audit_logs_detailed_retention_days.to_i

      return if summary_retention_days <= 0 && detailed_retention_days <= 0

      if summary_retention_days.positive?
        AiApiAuditLog
          .where("created_at < ?", summary_retention_days.days.ago)
          .in_batches(of: BATCH_SIZE)
          .delete_all
      end

      return if detailed_retention_days <= 0

      AiApiAuditLog
        .where("created_at < ?", detailed_retention_days.days.ago)
        .where("raw_request_payload IS NOT NULL OR raw_response_payload IS NOT NULL")
        .in_batches(of: BATCH_SIZE)
        .update_all(raw_request_payload: nil, raw_response_payload: nil)
    end
  end
end
