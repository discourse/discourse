# frozen_string_literal: true

Fabricator(:llm_credit_allocation) do
  llm_model
  daily_credits 33_334
  soft_limit_percentage 80

  transient :daily_used

  after_create do |allocation, transients|
    if transients[:daily_used]
      usage =
        LlmCreditDailyUsage.find_or_create_by!(
          llm_model_id: allocation.llm_model_id,
          usage_date: Date.current,
        )
      usage.update!(credits_used: transients[:daily_used])
    end
  end
end
