class AddHighestPostNumberToForumThreads < ActiveRecord::Migration[4.2]
  def change
    add_column :forum_threads, :highest_post_number, :integer, default: 0, null: false

    execute "UPDATE forum_threads SET highest_post_number = (SELECT MAX(post_number) FROM posts WHERE posts.forum_thread_id = forum_threads.id)"
  end
end
