class AddIndexToForumThreads < ActiveRecord::Migration
  def change
    add_index :forum_threads, :last_posted_at
  end
end
