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
end
