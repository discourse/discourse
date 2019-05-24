class AddUniqueIndexUserIdOnUserProfiles < ActiveRecord::Migration[5.2]
  def change
    add_index :user_profiles, :user_id, unique: true
  end
end
