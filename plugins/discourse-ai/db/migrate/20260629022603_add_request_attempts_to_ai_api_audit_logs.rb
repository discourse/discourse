# frozen_string_literal: true

class AddRequestAttemptsToAiApiAuditLogs < ActiveRecord::Migration[8.0]
  def up
    unless column_exists?(:ai_api_audit_logs, :request_attempts)
      add_column :ai_api_audit_logs, :request_attempts, :jsonb
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
