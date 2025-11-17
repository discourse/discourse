# frozen_string_literal: true
class CreateReviewableActionLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :reviewable_action_logs do |t|
      t.bigint :reviewable_id, null: false
      t.string :action_key, null: false
      t.integer :status, null: false
      t.integer :performed_by_id, null: false

      t.timestamps
    end

    add_index :reviewable_action_logs, :reviewable_id
    add_index :reviewable_action_logs, :performed_by_id
  end
end
