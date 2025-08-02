# frozen_string_literal: true

class MoveProfileBackgroundToUserProfiles < ActiveRecord::Migration[4.2]
  def up
    add_column :user_profiles, :profile_background, :string, limit: 255

    execute "UPDATE user_profiles SET profile_background = (SELECT profile_background FROM users WHERE user_profiles.user_id = users.id)"

    remove_column :users, :profile_background
  end

  def down
    add_column :users, :profile_background, :string, limit: 255

    execute "UPDATE users SET profile_background = (SELECT profile_background FROM user_profiles WHERE user_profiles.user_id = users.id)"

    remove_column :user_profiles, :profile_background
  end
end
