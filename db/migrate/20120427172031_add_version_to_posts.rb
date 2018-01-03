class AddVersionToPosts < ActiveRecord::Migration[4.2]
  def change
    add_column :posts, :cached_version, :integer, null: false, default: 1
  end
end
