class AddInvisibleToForumThread < ActiveRecord::Migration[4.2]
  def up
    add_column :forum_threads, :invisible, :boolean, default: false, null: false
    change_column :categories, :excerpt, :text, null: true
  end

  def down
    remove_column :forum_threads, :invisible
    change_column :categories, :excerpt, :string, limit: 250, null: true
  end

end
