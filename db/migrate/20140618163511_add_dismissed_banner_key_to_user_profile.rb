class AddDismissedBannerKeyToUserProfile < ActiveRecord::Migration[4.2]
  def change
    add_column :user_profiles, :dismissed_banner_key, :integer, nullable: true
  end
end
