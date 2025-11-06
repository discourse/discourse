# frozen_string_literal: true

Fabricator(:llm_credit_allocation) do
  llm_model
  monthly_credits 1_000_000
  monthly_usage { {} }
  soft_limit_percentage 80

  transient :monthly_used

  after_build do |allocation, transients|
    if transients[:monthly_used]
      month_key = Time.current.strftime("%Y-%m")
      allocation.monthly_usage = { month_key => transients[:monthly_used] }
    end
  end
end
