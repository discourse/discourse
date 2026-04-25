# frozen_string_literal: true
class AddPostIdIndexToAiApiAuditLogs < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    remove_index :ai_api_audit_logs, :post_id, algorithm: :concurrently, if_exists: true
    add_index :ai_api_audit_logs, :post_id, algorithm: :concurrently
  end
end
