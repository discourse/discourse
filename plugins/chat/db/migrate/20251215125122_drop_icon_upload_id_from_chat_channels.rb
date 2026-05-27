# frozen_string_literal: true

class DropIconUploadIdFromChatChannels < ActiveRecord::Migration[8.0]
  DROPPED_COLUMNS = { chat_channels: %i[icon_upload_id] }

  def up
    DROPPED_COLUMNS.each { |table, columns| Migration::ColumnDropper.execute_drop(table, columns) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
