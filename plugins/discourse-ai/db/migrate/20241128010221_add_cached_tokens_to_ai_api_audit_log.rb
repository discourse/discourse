# frozen_string_literal: true

class AddCachedTokensToAiApiAuditLog < ActiveRecord::Migration[7.2]
  def change
    add_column :ai_api_audit_logs, :cached_tokens, :integer
    add_index :ai_api_audit_logs, %i[created_at feature_name]
    add_index :ai_api_audit_logs, %i[created_at language_model]
  end
end
