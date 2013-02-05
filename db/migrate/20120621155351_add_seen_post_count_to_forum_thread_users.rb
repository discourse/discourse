class AddSeenPostCountToForumThreadUsers < ActiveRecord::Migration
  def change
    remove_column :post_timings, :id
    remove_column :forum_thread_users, :created_at
    remove_column :forum_thread_users, :updated_at
    add_column :forum_thread_users, :seen_post_count, :integer
  end
end
