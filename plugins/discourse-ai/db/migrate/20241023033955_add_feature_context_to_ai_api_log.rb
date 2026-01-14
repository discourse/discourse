# frozen_string_literal: true
#
class AddFeatureContextToAiApiLog < ActiveRecord::Migration[7.1]
  def change
    add_column :ai_api_audit_logs, :feature_context, :jsonb
  end
end
