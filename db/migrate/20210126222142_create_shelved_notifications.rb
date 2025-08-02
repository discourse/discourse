# frozen_string_literal: true
class CreateShelvedNotifications < ActiveRecord::Migration[6.0]
  def change
    create_table :shelved_notifications do |t|
      t.integer :notification_id, null: false
    end
    add_index :shelved_notifications, [:notification_id]
  end
end
