class RenameStickyToPinned < ActiveRecord::Migration
  def up
    rename_column :topics, :sticky, :pinned
  end

  def down
    rename_column :topics, :pinned, :sticky
  end
end
