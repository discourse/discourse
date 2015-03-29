class AddExpansionBackgroundToUserProfiles < ActiveRecord::Migration
  def change
    add_column :user_profiles, :expansion_background, :string, limit: 255
  end
end
