class AddNotificationIdToUserBadge < ActiveRecord::Migration[4.2]
  def change
    add_column :user_badges, :notification_id, :integer
  end
end
