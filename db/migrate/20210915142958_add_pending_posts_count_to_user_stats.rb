# frozen_string_literal: true

class AddPendingPostsCountToUserStats < ActiveRecord::Migration[6.1]
  def change
    add_column :user_stats, :pending_posts_count, :integer, null: false, default: 0
  end
end
