class RenameSeenPostCount < ActiveRecord::Migration
  def change
    rename_column :topic_users, :seen_post_count, :highest_seen_post_number
  end
end
