# frozen_string_literal: true

class IndexWorkflowAiAuditLogs < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  INDEX_NAME = "idx_ai_api_audit_logs_workflow_usage"

  def up
    remove_index :ai_api_audit_logs, name: INDEX_NAME, algorithm: :concurrently, if_exists: true
    add_index :ai_api_audit_logs,
              "(feature_context ->> 'workflow_id'), created_at",
              name: INDEX_NAME,
              where: "feature_name = 'workflow'",
              algorithm: :concurrently
  end

  def down
    remove_index :ai_api_audit_logs, name: INDEX_NAME, algorithm: :concurrently, if_exists: true
  end
end
