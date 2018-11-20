class AddIndexToForumThreads < ActiveRecord::Migration[4.2]
  def change
    add_index :forum_threads, :last_posted_at
  end
end
