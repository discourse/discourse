# frozen_string_literal: true

Fabricator(:llm_quota_usage) do
  user
  llm_quota
  input_tokens_used { 0 }
  output_tokens_used { 0 }
  usages { 0 }
  started_at { Time.current }
  reset_at { Time.current + 1.day }
end
