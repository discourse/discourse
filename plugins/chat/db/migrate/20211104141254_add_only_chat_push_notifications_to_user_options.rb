# frozen_string_literal: true
class AddOnlyChatPushNotificationsToUserOptions < ActiveRecord::Migration[6.1]
  def change
    add_column :user_options, :only_chat_push_notifications, :boolean, null: true
  end
end
