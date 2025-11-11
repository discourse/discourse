# frozen_string_literal: true

class AddFeatureNameToAiApiAuditLog < ActiveRecord::Migration[7.0]
  def change
    add_column :ai_api_audit_logs, :feature_name, :string, limit: 255
  end
end
