# frozen_string_literal: true

module Jobs
  class PurgeAiApiAuditLogs < ::Jobs::Scheduled
    every 1.day

    def execute(_args)
      return unless SiteSetting.discourse_ai_enabled

      retention_days = SiteSetting.ai_audit_logs_purge_after_days.to_i
      return if retention_days <= 0

      cutoff = retention_days.days.ago
      AiApiAuditLog.where("created_at < ?", cutoff).delete_all
    end
  end
end
