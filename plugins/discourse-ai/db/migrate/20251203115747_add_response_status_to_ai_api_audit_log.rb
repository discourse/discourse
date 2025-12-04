# frozen_string_literal: true
class AddResponseStatusToAiApiAuditLog < ActiveRecord::Migration[8.0]
  def change
    add_column :ai_api_audit_logs, :response_status, :integer
  end
end
