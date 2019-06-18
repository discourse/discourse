# frozen_string_literal: true

class AddFeaturedToForumThreads < ActiveRecord::Migration[4.2]
  def up
    add_column :forum_threads, :featured_user1_id, :integer, null: true
    add_column :forum_threads, :featured_user2_id, :integer, null: true
    add_column :forum_threads, :featured_user3_id, :integer, null: true
  end

  def down
    remove_column :forum_threads, :featured_user1_id
    remove_column :forum_threads, :featured_user2_id
    remove_column :forum_threads, :featured_user3_id
  end
end
