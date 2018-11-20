class AddSystemSavatarVersionToUserAvatars < ActiveRecord::Migration[4.2]
  def change
    add_column :user_avatars, :system_avatar_version, :integer, default: 0
  end
end
