class AddIsCachedToUserAvatar < ActiveRecord::Migration
  def change
    add_column :user_avatars, :is_cached, :boolean, default: false
  end
end
