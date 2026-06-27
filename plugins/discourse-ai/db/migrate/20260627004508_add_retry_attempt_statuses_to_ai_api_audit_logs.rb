# frozen_string_literal: true

class AddRetryAttemptStatusesToAiApiAuditLogs < ActiveRecord::Migration[8.0]
  def change
    add_column :ai_api_audit_logs,
               :retry_attempt_statuses,
               :integer,
               array: true,
               default: [],
               null: false
  end
end
