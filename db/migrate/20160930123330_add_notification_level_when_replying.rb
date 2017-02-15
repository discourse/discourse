class AddNotificationLevelWhenReplying < ActiveRecord::Migration
  def change
    add_column :user_options, :notification_level_when_replying, :integer
  end
end
