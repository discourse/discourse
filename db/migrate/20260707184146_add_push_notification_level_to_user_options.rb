# frozen_string_literal: true

class AddPushNotificationLevelToUserOptions < ActiveRecord::Migration[8.0]
  def change
    add_column :user_options, :push_notification_level, :integer, null: false, default: 0
  end
end
