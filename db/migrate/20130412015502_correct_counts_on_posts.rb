class CorrectCountsOnPosts < ActiveRecord::Migration
  def change
    rename_column :posts, :custom_flag_count, :notify_moderators_count
    add_column :posts, :notify_user_count, :integer, default: 0, null: false
  end
end
