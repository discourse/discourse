# frozen_string_literal: true

class AddTopicIdPostIdToAiAuditLog < ActiveRecord::Migration[7.0]
  def change
    add_column :ai_api_audit_logs, :topic_id, :integer
    add_column :ai_api_audit_logs, :post_id, :integer
  end
end
