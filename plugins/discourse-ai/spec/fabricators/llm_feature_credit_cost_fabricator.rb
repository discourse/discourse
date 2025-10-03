# frozen_string_literal: true

Fabricator(:llm_feature_credit_cost) do
  llm_model
  feature_name "ai_helper"
  credits_per_token 1.0
end
