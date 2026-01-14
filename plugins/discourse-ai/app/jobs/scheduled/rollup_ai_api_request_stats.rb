# frozen_string_literal: true

module Jobs
  class RollupAiApiRequestStats < ::Jobs::Scheduled
    every 1.day

    def execute(_args)
      return unless SiteSetting.discourse_ai_enabled
      return if SiteSetting.ai_usage_rollup_after_days.to_i <= 0

      AiApiRequestStat.rollup!
    end
  end
end
