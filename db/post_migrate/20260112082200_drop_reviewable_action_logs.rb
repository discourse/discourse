# frozen_string_literal: true
class DropReviewableActionLogs < ActiveRecord::Migration[8.0]
  def up
    drop_table :reviewable_action_logs
  end

  def down
    create_table :reviewable_action_logs do |t|
      t.bigint :reviewable_id, null: false
      t.string :action_key, null: false
      t.integer :status, null: false
      t.integer :performed_by_id, null: false
      t.string :bundle, default: "legacy-actions", null: false

      t.timestamps
    end

    add_index :reviewable_action_logs, :reviewable_id
    add_index :reviewable_action_logs, :performed_by_id
    add_index :reviewable_action_logs, :bundle
  end
end
