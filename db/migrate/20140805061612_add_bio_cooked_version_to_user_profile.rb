class AddBioCookedVersionToUserProfile < ActiveRecord::Migration
  def change
    add_column :user_profiles, :bio_cooked_version, :integer
    add_index :user_profiles, [:bio_cooked_version]
  end
end
