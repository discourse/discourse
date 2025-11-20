# frozen_string_literal: true

class DropCachedTokensFromAiApiAuditLogs < ActiveRecord::Migration[8.0]
  def up
    if column_exists?(:ai_api_audit_logs, :cached_tokens)
      remove_column :ai_api_audit_logs, :cached_tokens
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
