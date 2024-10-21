# frozen_string_literal: true

class DropOldChatMessagePostIdActionCodeColumns < ActiveRecord::Migration[7.0]
  DROPPED_COLUMNS = { chat_messages: %i[post_id action_code] }

  def up
    DROPPED_COLUMNS.each { |table, columns| Migration::ColumnDropper.execute_drop(table, columns) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
