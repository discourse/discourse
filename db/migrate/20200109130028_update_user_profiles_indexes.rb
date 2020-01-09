# frozen_string_literal: true

class UpdateUserProfilesIndexes < ActiveRecord::Migration[6.0]
  def change
    remove_index :user_profiles, :card_background
    add_index :user_profiles, :card_background_upload_id

    remove_index :user_profiles, :profile_background
    add_index :user_profiles, :profile_background_upload_id
  end
end
