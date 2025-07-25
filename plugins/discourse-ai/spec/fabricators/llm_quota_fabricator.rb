# frozen_string_literal: true

Fabricator(:llm_quota) do
  group
  llm_model
  max_tokens { 1000 }
  max_usages { 10 }
  duration_seconds { 1.day.to_i }
end
