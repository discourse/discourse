class AddForumIdToCategories < ActiveRecord::Migration
  def up
    add_column :categories, :forum_id, :integer
    execute "UPDATE categories SET forum_id = (SELECT MIN(id) FROM forums)"
    change_column :categories, :forum_id, :integer, null: false
  end

  def down
    remove_column :categories, :forum_id
  end

end
