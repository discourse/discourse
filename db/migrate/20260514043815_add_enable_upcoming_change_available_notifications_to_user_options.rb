# frozen_string_literal: true

class AddEnableUpcomingChangeAvailableNotificationsToUserOptions < ActiveRecord::Migration[8.0]
  def change
    add_column :user_options,
               :enable_upcoming_change_available_notifications,
               :boolean,
               default: true,
               null: false
  end
end
