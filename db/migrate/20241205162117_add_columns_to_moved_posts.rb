# frozen_string_literal: true
class AddColumnsToMovedPosts < ActiveRecord::Migration[7.2]
  def change
    add_column :moved_posts, :old_topic_title, :string
    add_column :moved_posts, :post_user_id, :integer
    add_column :moved_posts, :user_id, :integer

    # Index for querying moved_posts for post author given a new topic ID
    add_index :moved_posts, %i[new_topic_id post_user_id]
  end
end
