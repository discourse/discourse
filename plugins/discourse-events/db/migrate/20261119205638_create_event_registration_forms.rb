# frozen_string_literal: true
class CreateEventRegistrationForms < ActiveRecord::Migration[8.1]
  def change
    create_table :discourse_event_registration_forms do |t|
      t.jsonb :definition, null: false
      t.timestamps
    end
    add_column :discourse_post_event_events, :registration_form_id, :bigint
  end
end
