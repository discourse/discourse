class AddUserProfilesIndexes < ActiveRecord::Migration[4.2]
  def change
    add_index :user_profiles, :profile_background
    add_index :user_profiles, :card_background
  end
end
