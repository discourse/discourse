# frozen_string_literal: true

class CreateNotifications < ActiveRecord::Migration[4.2]
  def change
    create_table :notifications do |t|
      t.integer :notification_type, null: false
      t.references :user, null: false
      t.string :data, null: false
      t.boolean :read, default: false, null: false
      t.timestamps null: false
    end

    add_index :notifications, [:user_id, :created_at]
  end
end
