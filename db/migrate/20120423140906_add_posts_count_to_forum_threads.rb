class AddPostsCountToForumThreads < ActiveRecord::Migration[4.2]
  def change
    add_column :forum_threads, :posts_count, :integer, default: 0, null: false

    execute "UPDATE forum_threads SET posts_count = (SELECT count(*) FROM posts WHERE posts.forum_thread_id = forum_threads.id)"
  end
end
