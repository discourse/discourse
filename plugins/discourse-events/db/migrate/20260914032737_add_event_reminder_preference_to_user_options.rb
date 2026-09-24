# frozen_string_literal: true

class AddEventReminderPreferenceToUserOptions < ActiveRecord::Migration[8.0]
  def change
    add_column :user_options, :event_reminder_preference, :integer, default: 0, null: false
  end
end
