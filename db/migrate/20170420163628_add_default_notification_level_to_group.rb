class AddDefaultNotificationLevelToGroup < ActiveRecord::Migration[4.2]
  def up
    add_column :groups, :default_notification_level, :integer, default: 3, null: false
    # don't auto watch 'moderators' it is just way too loud
    execute 'UPDATE groups SET default_notification_level = 2 WHERE id = 2'
  end

  def down
    remove_column :groups, :default_notification_level
  end
end
