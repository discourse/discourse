# frozen_string_literal: true

class DropChatThreadTitleTemplateFromVoiceRooms < ActiveRecord::Migration[8.0]
  DROPPED_COLUMNS = { voice_rooms: %i[chat_thread_title_template] }

  def up
    DROPPED_COLUMNS.each { |table, columns| Migration::ColumnDropper.execute_drop(table, columns) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
