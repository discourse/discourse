# frozen_string_literal: true

class DropChatChannelsLastMessageSentAt < ActiveRecord::Migration[7.0]
  DROPPED_COLUMNS = { chat_channels: %i[last_message_sent_at] }.freeze

  def up
    DROPPED_COLUMNS.each { |table, columns| Migration::ColumnDropper.execute_drop(table, columns) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
