class AddNotificationIdToUserBadge < ActiveRecord::Migration
  def change
    add_column :user_badges, :notification_id, :integer
  end
end
