# frozen_string_literal: true

class CreateUpcomingChangeEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :upcoming_change_events do |t|
      t.integer :event_type, null: false
      t.string :upcoming_change_name, null: false
      t.json :event_data
      t.bigint :acting_user_id

      t.timestamps
    end

    add_index :upcoming_change_events, :event_type
    add_index :upcoming_change_events, :upcoming_change_name
    add_index :upcoming_change_events,
              %i[upcoming_change_name event_type],
              unique: true,
              name: "idx_upcoming_change_events_unique_once_off",
              where: "event_type IN (0, 1, 6, 7)" # added, removed, admins_notified_available_change, admins_notified_automatic_promotion
  end
end
