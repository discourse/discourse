# frozen_string_literal: true

module Jobs
  class PurgeOldLlmCreditUsage < ::Jobs::Scheduled
    every 1.day

    def execute(_args)
      return unless SiteSetting.discourse_ai_enabled

      retention_days = LlmCreditAllocation::DAILY_USAGE_RETENTION_DAYS
      LlmCreditDailyUsage.cleanup_old_records!(retention_days)
    end
  end
end
