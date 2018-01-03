class AddRepliesToForumThreads < ActiveRecord::Migration[4.2]
  def change
    add_column :forum_threads, :reply_count, :integer, default: 0, null: false

    execute "UPDATE forum_threads SET reply_count = (SELECT COUNT(*) FROM posts WHERE posts.reply_to_post_number IS NOT NULL AND posts.forum_thread_id = forum_threads.id)"
  end
end
