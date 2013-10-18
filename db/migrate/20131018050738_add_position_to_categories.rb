class AddPositionToCategories < ActiveRecord::Migration
  def up
    add_column :categories, :position, :integer
    execute "UPDATE categories SET position = id"
    change_column :categories, :position, :integer, null: false
  end

  def down
    remove_column :categories, :position
  end
end
