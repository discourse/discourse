# frozen_string_literal: true

require 'migration/column_dropper'

class DropOldBookmarkColumnsV2 < ActiveRecord::Migration[7.0]
  DROPPED_COLUMNS ||= {
    bookmarks: %i{
      post_id
      for_topic
    }
  }

  def up
    DROPPED_COLUMNS.each do |table, columns|
      Migration::ColumnDropper.execute_drop(table, columns)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
