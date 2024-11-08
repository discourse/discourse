# frozen_string_literal: true

class DropNotificationIdFromChatMentions < ActiveRecord::Migration[7.0]
  DROPPED_COLUMNS = { chat_mentions: %i[notification_id] }.freeze

  def up
    DROPPED_COLUMNS.each { |table, columns| Migration::ColumnDropper.execute_drop(table, columns) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
