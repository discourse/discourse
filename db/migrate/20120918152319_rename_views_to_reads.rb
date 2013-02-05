class RenameViewsToReads < ActiveRecord::Migration
  def up
    rename_column :posts, :views, :reads
  end

  def down
    rename_column :posts, :reads, :views
  end
end
