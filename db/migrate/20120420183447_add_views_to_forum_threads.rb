class AddViewsToForumThreads < ActiveRecord::Migration
  def change
    add_column :forum_threads, :views, :integer, default: 0, null: false
  end
end
