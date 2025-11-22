# frozen_string_literal: true

class AddLlmIdToAiApiAuditLogs < ActiveRecord::Migration[8.0]
  def change
    add_column :ai_api_audit_logs, :llm_id, :integer
    add_index :ai_api_audit_logs, [:llm_id]
  end
end
