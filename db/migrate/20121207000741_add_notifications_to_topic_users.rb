class AddNotificationsToTopicUsers < ActiveRecord::Migration
  def change
    add_column :topic_users, :notifications, :integer, default: 2
    add_column :topic_users, :notifications_changed_at, :datetime
    add_column :topic_users, :notifications_reason_id, :integer
  end
end
