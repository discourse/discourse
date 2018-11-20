class CorrectDefaultOnNotificationLevel < ActiveRecord::Migration[4.2]
  def change
    change_column :topic_users, :notification_level, :integer, default: 1, null: false
  end
end
