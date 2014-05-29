class AddSystemSavatarVersionToUserAvatars < ActiveRecord::Migration
  def change
    add_column :user_avatars, :system_avatar_version, :integer, default: 0
  end
end
