# frozen_string_literal: true

module Jobs
  class FlushDecisionModelCreditUsage < ::Jobs::Base
    def execute(_args)
      DecisionModelCreditDailyUsage.flush_pending!
    end
  end
end
