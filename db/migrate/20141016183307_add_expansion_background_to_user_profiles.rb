class AddExpansionBackgroundToUserProfiles < ActiveRecord::Migration[4.2]
  def change
    add_column :user_profiles, :expansion_background, :string, limit: 255
  end
end
