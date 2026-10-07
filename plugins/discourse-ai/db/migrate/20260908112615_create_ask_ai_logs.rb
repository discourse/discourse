# frozen_string_literal: true

class CreateAskAiLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :ask_ai_logs do |t|
      t.bigint :user_id, null: false
      t.text :query, null: false
      t.text :keyword_query
      t.text :semantic_query
      t.string :query_locale
      t.bigint :candidate_post_ids, array: true, default: [], null: false
      t.bigint :source_post_ids, array: true, default: [], null: false
      t.text :answer_title
      t.text :answer
      t.text :suggested_follow_up
      t.integer :ask_outcome
      t.integer :failure_stage
      t.datetime :asked_at, null: false
      t.integer :time_to_first_answer_ms
      t.timestamps
    end

    add_index :ask_ai_logs, :asked_at
    add_index :ask_ai_logs, %i[user_id asked_at]
  end
end
