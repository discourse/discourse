# frozen_string_literal: true

Fabricator(:llm_credit_allocation) do
  llm_model
  monthly_credits 1_000_000
  monthly_used 0
  last_reset_at { Time.current.beginning_of_month }
  soft_limit_percentage 80
end
