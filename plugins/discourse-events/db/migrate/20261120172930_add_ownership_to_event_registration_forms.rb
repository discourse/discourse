# frozen_string_literal: true
class AddOwnershipToEventRegistrationForms < ActiveRecord::Migration[8.1]
  def change
    change_table :discourse_event_registration_forms, bulk: true do |t|
      t.integer :created_by_id
      t.datetime :deleted_at
      t.integer :deleted_by_id
    end
  end
end
