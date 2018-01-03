class AddViewCountToPosts < ActiveRecord::Migration[4.2]
  def change
    add_column :posts, :views, :integer, default: 0, null: false

    execute "UPDATE posts SET views =
              (SELECT COUNT(*) FROM post_timings WHERE forum_thread_id = posts.forum_thread_id AND post_number = posts.post_number)"
  end
end
