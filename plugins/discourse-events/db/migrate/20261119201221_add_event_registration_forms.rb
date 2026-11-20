# frozen_string_literal: true

class AddEventRegistrationForms < ActiveRecord::Migration[8.1]
  def change
    add_column :discourse_post_event_events, :registration_form, :jsonb
    add_column :discourse_post_event_events, :registration_topic_id, :bigint

    create_table :discourse_event_registrations do |t|
      t.bigint :event_id, null: false
      t.integer :user_id, null: false
      t.uuid :submission_key, null: false
      t.string :username, null: false
      t.string :email, null: false
      t.datetime :occurrence_starts_at, null: false
      t.boolean :recurring, null: false
      t.jsonb :definition, null: false
      t.jsonb :answers, null: false
      t.bigint :report_post_id
      t.timestamps
    end
    add_index :discourse_event_registrations, %i[event_id user_id submission_key], unique: true
  end
end
