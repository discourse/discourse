class AddCardImageToUserProfiles < ActiveRecord::Migration
  def change
    add_column :user_profiles, :card_image_badge_id, :integer
  end
end
