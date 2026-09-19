# frozen_string_literal: true

class AddPushNotificationLevelToUserOptions < ActiveRecord::Migration[8.0]
  def change
    # push_notification_level enum: none: 0, all: 1, chat_only: 2. Default to `all`
    # to preserve the prior behaviour where push notifications were enabled.
    add_column :user_options, :push_notification_level, :integer, null: false, default: 1
  end
end
