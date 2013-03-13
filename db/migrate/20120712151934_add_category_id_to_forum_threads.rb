class AddCategoryIdToForumThreads < ActiveRecord::Migration
  def up
    add_column :forum_threads, :category_id, :integer

    execute "UPDATE forum_threads SET category_id =
             (SELECT id
              FROM categories
              WHERE name = forum_threads.tag)"

    remove_column :forum_threads, :tag
  end

  def down
    remove_column :forum_threads, :category_id
    add_column :forum_threads, :tag, :string, limit: 20
  end

end
