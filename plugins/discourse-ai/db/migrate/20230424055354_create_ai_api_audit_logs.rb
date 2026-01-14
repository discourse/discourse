# frozen_string_literal: true

class CreateAiApiAuditLogs < ActiveRecord::Migration[7.0]
  def change
    create_table :ai_api_audit_logs do |t|
      t.integer :provider_id, null: false
      t.integer :user_id
      t.integer :request_tokens
      t.integer :response_tokens
      t.string :raw_request_payload
      t.string :raw_response_payload
      t.timestamps
    end
  end
end
