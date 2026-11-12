# frozen_string_literal: true

class AddCostToLlmQuotasAndAiUsage < ActiveRecord::Migration[8.0]
  def change
    add_column :llm_quotas, :max_cost, :decimal, precision: 20, scale: 10
    add_column :llm_quota_usages,
               :cost_used,
               :decimal,
               precision: 20,
               scale: 10,
               default: 0,
               null: false
    add_column :llm_quota_usages, :cache_read_tokens_used, :integer, default: 0, null: false
    add_column :llm_quota_usages, :cache_write_tokens_used, :integer, default: 0, null: false
    add_column :ai_api_audit_logs, :estimated_cost, :decimal, precision: 20, scale: 10
    add_column :ai_api_request_stats, :estimated_cost, :decimal, precision: 20, scale: 10
  end
end
