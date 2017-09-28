class ChangeDefaultNotificationLevelOnGroups < ActiveRecord::Migration[4.2]
  def change
    execute "UPDATE group_users SET notification_level = 2"
    change_column :group_users, :notification_level, :integer, null: false, default: 2
  end
end
