# frozen_string_literal: true

class DropBookmarkPolymorphicColumns < ActiveRecord::Migration[6.1]
  DROPPED_COLUMNS ||= {
    bookmarks: %i{bookmarkable_id bookmarkable_type}
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
