# frozen_string_literal: true
class AddAutomationStats < ActiveRecord::Migration[7.2]
  def change
    create_table :discourse_automation_stats do |t|
      t.bigint :automation_id, null: false
      t.date :date, null: false
      t.datetime :last_run_at, null: false
      t.float :total_time, null: false
      t.float :average_run_time, null: false
      t.float :min_run_time, null: false
      t.float :max_run_time, null: false
      t.integer :total_runs, null: false
    end

    add_index :discourse_automation_stats, %i[automation_id date], unique: true
  end
end
