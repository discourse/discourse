# frozen_string_literal: true

class AddUserIdIdIndexToAiApiAuditLogs < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  INDEX_NAME = "idx_ai_api_audit_logs_user_id_id"

  def up
    remove_index :ai_api_audit_logs, name: INDEX_NAME, algorithm: :concurrently, if_exists: true
    add_index :ai_api_audit_logs, %i[user_id id], name: INDEX_NAME, algorithm: :concurrently
  end

  def down
    remove_index :ai_api_audit_logs, name: INDEX_NAME, algorithm: :concurrently, if_exists: true
  end
end
