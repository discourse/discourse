# frozen_string_literal: true

module Jobs
  class CleanUpMcpRecords < ::Jobs::Scheduled
    BATCH_SIZE = 1_000

    every 1.day

    def execute(_args)
      now = Time.zone.now
      McpOauthAuthorizationCode.where("expires_at < ?", now).in_batches(of: BATCH_SIZE).delete_all
      McpOauthAccessToken.where("expires_at < ?", 30.days.ago).in_batches(of: BATCH_SIZE).delete_all
      McpOauthRefreshToken
        .where("expires_at < ?", 30.days.ago)
        .in_batches(of: BATCH_SIZE)
        .delete_all
      McpAuditLog
        .where("occurred_at < ?", SiteSetting.mcp_audit_log_retention_days.days.ago)
        .in_batches(of: BATCH_SIZE)
        .delete_all
    end
  end
end
