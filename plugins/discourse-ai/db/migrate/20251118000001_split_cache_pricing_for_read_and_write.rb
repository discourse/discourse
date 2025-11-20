# frozen_string_literal: true

class SplitCachePricingForReadAndWrite < ActiveRecord::Migration[7.2]
  def up
    add_column :llm_models, :cache_write_cost, :float, default: 0.0
    add_column :ai_api_audit_logs, :cache_write_tokens, :integer
    add_column :ai_api_audit_logs, :cache_read_tokens, :integer
    execute "UPDATE ai_api_audit_logs SET cache_read_tokens = cached_tokens WHERE cached_tokens IS NOT NULL"
  end

  def down
    remove_column :ai_api_audit_logs, :cache_read_tokens
    remove_column :ai_api_audit_logs, :cache_write_tokens
    remove_column :llm_models, :cache_write_cost
  end
end
