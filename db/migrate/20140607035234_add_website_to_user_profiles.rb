class AddWebsiteToUserProfiles < ActiveRecord::Migration[4.2]
  def up
    add_column :user_profiles, :website, :string

    execute "UPDATE user_profiles SET website = (SELECT website FROM users where user_profiles.user_id = users.id)"

    remove_column :users, :website
  end

  def down
    add_column :users, :website, :string

    execute "UPDATE users SET website = (SELECT website FROM user_profiles where user_profiles.user_id = users.id)"

    remove_column :user_profiles, :website
  end
end
