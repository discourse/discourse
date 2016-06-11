class CreateSchedulerStats < ActiveRecord::Migration
  def change
    create_table :scheduler_stats do |t|
      t.string :name, null: false
      t.string :hostname, null: false
      t.integer :pid, null: false
      t.integer :duration_ms
      t.integer :live_slots_start
      t.integer :live_slots_finish
      t.datetime :started_at, null: false
      t.boolean :success
    end
  end
end
