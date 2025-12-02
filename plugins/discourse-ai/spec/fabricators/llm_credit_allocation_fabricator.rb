# frozen_string_literal: true

Fabricator(:llm_credit_allocation) do
  llm_model
  daily_credits 33_334
  daily_usage { {} }
  soft_limit_percentage 80

  transient :daily_used

  after_build do |allocation, transients|
    if transients[:daily_used]
      day_key = Time.current.utc.strftime("%Y-%m-%d")
      allocation.daily_usage = { day_key => transients[:daily_used] }
    end
  end

  after_create do |allocation, transients|
    if transients[:daily_used]
      # Also create the daily usage record in the new table
      LlmCreditDailyUsage
        .find_or_create_by!(
          llm_model_id: allocation.llm_model_id,
          usage_date: Date.current,
        ) { |usage| usage.credits_used = transients[:daily_used] }
        .update!(credits_used: transients[:daily_used])
    end
  end
end
