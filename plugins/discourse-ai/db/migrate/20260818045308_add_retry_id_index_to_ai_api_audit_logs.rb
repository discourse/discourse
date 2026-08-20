# frozen_string_literal: true

class AddRetryIdIndexToAiApiAuditLogs < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  INDEX_NAME = "idx_ai_api_audit_logs_retried_id"

  def up
    remove_index :ai_api_audit_logs, name: INDEX_NAME, algorithm: :concurrently, if_exists: true
    add_index :ai_api_audit_logs,
              :id,
              name: INDEX_NAME,
              where: "request_attempts IS NOT NULL",
              algorithm: :concurrently
  end

  def down
    remove_index :ai_api_audit_logs, name: INDEX_NAME, algorithm: :concurrently, if_exists: true
  end
end
