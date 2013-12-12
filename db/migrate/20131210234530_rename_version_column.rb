class RenameVersionColumn < ActiveRecord::Migration

  def change
    add_column :posts, :version, :integer, default: 1, null: false
    execute "UPDATE posts SET version = cached_version"
    remove_column :posts, :cached_version
  end

end
