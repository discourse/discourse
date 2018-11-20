class AddNotificationLevelWhenReplying < ActiveRecord::Migration[4.2]
  def change
    add_column :user_options, :notification_level_when_replying, :integer
  end
end
