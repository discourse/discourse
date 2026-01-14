# frozen_string_literal: true
class AddLanguageModelToAiAuditLogs < ActiveRecord::Migration[7.0]
  def change
    add_column :ai_api_audit_logs, :language_model, :string, limit: 255
  end
end
