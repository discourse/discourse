# frozen_string_literal: true

class AddPushNotificationLevelToUserOptions < ActiveRecord::Migration[8.0]
  def up
    add_column :user_options, :push_notification_level, :integer, null: false, default: 0

    # `only_chat_push_notifications` is being replaced by `push_notification_level`.
    # Mark it readonly so it can be safely dropped in a later post-deploy migration.
    change_column_default :user_options, :only_chat_push_notifications, nil
    Migration::ColumnDropper.mark_readonly(:user_options, :only_chat_push_notifications)
  end

  def down
    Migration::ColumnDropper.drop_readonly(:user_options, :only_chat_push_notifications)
    remove_column :user_options, :push_notification_level
  end
end
