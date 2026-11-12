# frozen_string_literal: true

class AddFailedIdIndexToAiApiAuditLogs < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  INDEX_NAME = "idx_ai_api_audit_logs_failed_id"
  FAILURE_CONDITION =
    "(response_status IS NOT NULL AND response_status NOT BETWEEN 200 AND 299) OR " \
      "(response_status IS NULL AND COALESCE(response_tokens, 0) <= 0)"

  def up
    remove_index :ai_api_audit_logs, name: INDEX_NAME, algorithm: :concurrently, if_exists: true
    add_index :ai_api_audit_logs,
              :id,
              name: INDEX_NAME,
              where: FAILURE_CONDITION,
              algorithm: :concurrently
  end

  def down
    remove_index :ai_api_audit_logs, name: INDEX_NAME, algorithm: :concurrently, if_exists: true
  end
end
