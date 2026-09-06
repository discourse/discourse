# frozen_string_literal: true

class AddFeatureNameIdIndexToAiApiAuditLogs < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  INDEX_NAME = "idx_ai_api_audit_logs_feature_name_id"

  def up
    remove_index :ai_api_audit_logs, name: INDEX_NAME, algorithm: :concurrently, if_exists: true
    add_index :ai_api_audit_logs,
              %i[feature_name id],
              name: INDEX_NAME,
              where: "feature_name IS NOT NULL",
              algorithm: :concurrently
  end

  def down
    remove_index :ai_api_audit_logs, name: INDEX_NAME, algorithm: :concurrently, if_exists: true
  end
end
