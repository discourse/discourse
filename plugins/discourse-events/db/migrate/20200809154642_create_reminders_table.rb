# frozen_string_literal: true

class CreateRemindersTable < ActiveRecord::Migration[6.0]
  def change
    create_table :discourse_post_event_reminders do |t|
      t.integer :post_id, null: false
      t.integer :value, null: false, default: 0
      t.integer :mean, null: false, default: 0
      t.string :unit, null: false, default: "minutes"
    end
  end
end
