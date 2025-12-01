# frozen_string_literal: true

class AddUserIdIndexToAiApiAuditLogs < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    user_idx = "index_ai_api_audit_logs_on_created_at_and_user_id"
    execute "DROP INDEX IF EXISTS #{user_idx}"
    add_index :ai_api_audit_logs, %i[created_at user_id], name: user_idx

    topic_idx = "index_ai_api_audit_logs_on_topic_id"
    execute "DROP INDEX IF EXISTS #{topic_idx}"
    add_index :ai_api_audit_logs, [:topic_id], name: topic_idx
  end
end
