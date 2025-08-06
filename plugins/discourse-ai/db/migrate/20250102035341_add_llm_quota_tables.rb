# frozen_string_literal: true

class AddLlmQuotaTables < ActiveRecord::Migration[7.2]
  def change
    create_table :llm_quotas do |t|
      t.bigint :group_id, null: false
      t.bigint :llm_model_id, null: false
      t.integer :max_tokens
      t.integer :max_usages
      t.integer :duration_seconds, null: false
      t.timestamps
    end

    add_index :llm_quotas, :llm_model_id
    add_index :llm_quotas, %i[group_id llm_model_id], unique: true

    create_table :llm_quota_usages do |t|
      t.bigint :user_id, null: false
      t.bigint :llm_quota_id, null: false
      t.integer :input_tokens_used, null: false
      t.integer :output_tokens_used, null: false
      t.integer :usages, null: false
      t.datetime :started_at, null: false
      t.datetime :reset_at, null: false
      t.timestamps
    end

    add_index :llm_quota_usages, :llm_quota_id
    add_index :llm_quota_usages, %i[user_id llm_quota_id], unique: true
  end
end
