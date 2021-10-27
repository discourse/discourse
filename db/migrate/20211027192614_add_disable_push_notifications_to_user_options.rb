# frozen_string_literal: true

class AddDisablePushNotificationsToUserOptions < ActiveRecord::Migration[6.1]
  def change
    add_column :user_options, :push_notifications_disabled, :boolean, null: true
    add_index :user_options, [:push_notifications_disabled]
  end
end
