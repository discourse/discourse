class AddUserProfilesIndexes < ActiveRecord::Migration
  def change
    add_index :user_profiles, :profile_background
    add_index :user_profiles, :card_background
  end
end
