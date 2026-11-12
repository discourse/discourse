# frozen_string_literal: true

class AddCompletionStateToAiApiAuditLogs < ActiveRecord::Migration[8.0]
  def change
    add_column :ai_api_audit_logs, :completion_state, :integer, limit: 2
    add_column :ai_api_audit_logs, :reasoning_tokens, :integer
    add_column :ai_api_audit_logs, :stop_reason, :string, limit: 50
  end
end
