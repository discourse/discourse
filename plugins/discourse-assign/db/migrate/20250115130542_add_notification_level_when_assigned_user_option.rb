# frozen_string_literal: true
class AddNotificationLevelWhenAssignedUserOption < ActiveRecord::Migration[7.2]
  def change
    add_column :user_options, :notification_level_when_assigned, :integer, null: false, default: 3 # watch topic
  end
end
