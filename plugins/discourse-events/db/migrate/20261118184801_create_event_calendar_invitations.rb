# frozen_string_literal: true

class CreateEventCalendarInvitations < ActiveRecord::Migration[8.1]
  def change
    create_table :discourse_event_calendar_invitations do |t|
      t.bigint :event_id, null: false
      t.bigint :user_id, null: false
      t.string :uid, null: false
      t.string :organizer, null: false
      t.string :recipient, null: false
      t.jsonb :snapshot, null: false, default: {}
      t.jsonb :delivered_snapshot, null: false, default: {}
      t.integer :sequence, null: false, default: 0
      t.integer :delivered_sequence, null: false, default: -1
      t.boolean :cancelled, null: false, default: false
      t.timestamps
    end
    add_index :discourse_event_calendar_invitations, %i[event_id user_id], unique: true
    add_index :discourse_event_calendar_invitations, :user_id
  end
end
