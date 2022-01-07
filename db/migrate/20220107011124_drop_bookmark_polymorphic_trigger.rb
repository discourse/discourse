# frozen_string_literal: true

class DropBookmarkPolymorphicTrigger < ActiveRecord::Migration[6.1]
  def up
    DB.exec("DROP TRIGGER IF EXISTS bookmarks_polymorphic_data_sync ON bookmarks")
    DB.exec("DROP FUNCTION IF EXISTS sync_bookmarks_polymorphic_column_data")
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
