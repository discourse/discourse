# frozen_string_literal: true

class DropChatMentionNotificationsOldIdColumn < ActiveRecord::Migration[7.1]
  DROPPED_COLUMNS ||= { chat_mention_notifications: %i[old_notification_id] }

  def up
    DROPPED_COLUMNS.each { |table, columns| Migration::ColumnDropper.execute_drop(table, columns) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
