# frozen_string_literal: true

class AddTimeToFirstTokenToAiApiAuditLogs < ActiveRecord::Migration[8.0]
  def change
    add_column :ai_api_audit_logs, :time_to_first_token_msecs, :integer
  end
end
