# frozen_string_literal: true

Fabricator(:decision_model_credit_allocation) do
  decision_model { Fabricate(:decision_model, id: -1) }
  daily_credits 10_000
  soft_limit_percentage 80

  transient :daily_used

  after_create do |allocation, transients|
    if transients[:daily_used]
      DecisionModelCreditDailyUsage.create!(
        decision_model_id: allocation.decision_model_id,
        usage_date: Date.current,
        credits_used: transients[:daily_used],
      )
    end
  end
end
