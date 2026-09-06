# frozen_string_literal: true

Fabricator(:llm_quota_usage) do
  user
  llm_quota
  input_tokens_used { 0 }
  output_tokens_used { 0 }
  cache_read_tokens_used { 0 }
  cache_write_tokens_used { 0 }
  cost_used { 0 }
  usages { 0 }
  started_at { Time.current }
  reset_at { 1.day.from_now }
end
