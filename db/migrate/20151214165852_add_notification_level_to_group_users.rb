class AddNotificationLevelToGroupUsers < ActiveRecord::Migration[4.2]
  def change
    # defaults to TopicUser.notification_levels[:watching]
    add_column :group_users, :notification_level, :integer, default: 3, null: false
  end
end
