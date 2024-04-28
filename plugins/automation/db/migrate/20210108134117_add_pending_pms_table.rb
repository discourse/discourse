# frozen_string_literal: true

class AddPendingPmsTable < ActiveRecord::Migration[6.0]
  def change
    create_table :discourse_automation_pending_pms do |t|
      t.string :target_usernames, array: true
      t.string :sender
      t.string :title
      t.string :raw
      t.integer :automation_id, null: false
      t.datetime :execute_at, null: false
      t.timestamps null: false
    end
  end
end
