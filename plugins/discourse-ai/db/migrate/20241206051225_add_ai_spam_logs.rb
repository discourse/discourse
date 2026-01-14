# frozen_string_literal: true
class AddAiSpamLogs < ActiveRecord::Migration[7.2]
  def change
    create_table :ai_spam_logs do |t|
      t.bigint :post_id, null: false
      t.bigint :llm_model_id, null: false
      t.bigint :ai_api_audit_log_id
      t.bigint :reviewable_id
      t.boolean :is_spam, null: false
      t.string :payload, null: false, default: "", limit: 20_000
      t.timestamps
    end

    add_index :ai_spam_logs, :post_id
  end
end
