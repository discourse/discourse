class RemoveHasCustomAvatarFromUserStats < ActiveRecord::Migration
  def change
    remove_column :user_stats, :has_custom_avatar
  end
end
