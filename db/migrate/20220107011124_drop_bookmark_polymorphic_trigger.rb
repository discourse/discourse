# frozen_string_literal: true

class DropBookmarkPolymorphicTrigger < ActiveRecord::Migration[6.1]
  def up
    DB.exec("DROP FUNCTION IF EXISTS sync_bookmarks_polymorphic_column_data CASCADE")
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
