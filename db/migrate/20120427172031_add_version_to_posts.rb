class AddVersionToPosts < ActiveRecord::Migration
  def change
    add_column :posts, :cached_version, :integer, null: false, default: 1
  end
end
