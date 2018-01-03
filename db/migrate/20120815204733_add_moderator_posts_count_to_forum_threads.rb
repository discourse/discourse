class AddModeratorPostsCountToForumThreads < ActiveRecord::Migration[4.2]
  def change
    add_column :forum_threads, :moderator_posts_count, :integer, default: 0, null: false

    execute "UPDATE forum_threads
             SET moderator_posts_count = (SELECT COUNT(*)
                                          FROM posts WHERE posts.forum_thread_id = forum_threads.id
                                            AND posts.post_type = 2)"
  end
end
