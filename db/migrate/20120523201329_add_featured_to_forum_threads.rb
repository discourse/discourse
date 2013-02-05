class AddFeaturedToForumThreads < ActiveRecord::Migration
  def up
    add_column :forum_threads, :featured_user1_id, :integer, null: true
    add_column :forum_threads, :featured_user2_id, :integer, null: true
    add_column :forum_threads, :featured_user3_id, :integer, null: true

    # Migrate old threads
    ForumThread.all.each do |forum_thread|
      posts_count = Post.where(forum_thread_id: forum_thread.id).group(:user_id).order('count_all desc').limit(3).count
      posts_count.keys.each_with_index {|user_id, i| forum_thread.send("featured_user#{i+1}_id=", user_id) }
      forum_thread.save
    end

  end

  def down
    remove_column :forum_threads, :featured_user1_id
    remove_column :forum_threads, :featured_user2_id
    remove_column :forum_threads, :featured_user3_id
  end
end
