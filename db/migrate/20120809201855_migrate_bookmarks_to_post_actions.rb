class MigrateBookmarksToPostActions < ActiveRecord::Migration[4.2]
  def up
    drop_table "bookmarks"
  end

  def down
    # I can reverse this, but not really worth the work
    raise ActiveRecord::IrreversibleMigration
  end
end
