# frozen_string_literal: true

class CreateUserNotificationSchedules < ActiveRecord::Migration[6.0]
  def change
    create_table :user_notification_schedules do |t|
      t.integer :user_id, null: false
      t.boolean :enabled, null: false, default: false
      t.integer :day_0_start_time, null: false
      t.integer :day_0_end_time, null: false
      t.integer :day_1_start_time, null: false
      t.integer :day_1_end_time, null: false
      t.integer :day_2_start_time, null: false
      t.integer :day_2_end_time, null: false
      t.integer :day_3_start_time, null: false
      t.integer :day_3_end_time, null: false
      t.integer :day_4_start_time, null: false
      t.integer :day_4_end_time, null: false
      t.integer :day_5_start_time, null: false
      t.integer :day_5_end_time, null: false
      t.integer :day_6_start_time, null: false
      t.integer :day_6_end_time, null: false
    end

    add_index :user_notification_schedules, [:user_id]
    add_index :user_notification_schedules, [:enabled]

    add_column :do_not_disturb_timings, :scheduled, :boolean, default: false
    add_index :do_not_disturb_timings, [:scheduled]
  end
end
