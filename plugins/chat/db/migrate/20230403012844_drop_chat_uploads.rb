# frozen_string_literal: true

class DropChatUploads < ActiveRecord::Migration[7.0]
  DROPPED_TABLES = %i[chat_uploads]

  def up
    DROPPED_TABLES.each { |table| Migration::TableDropper.execute_drop(table) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
