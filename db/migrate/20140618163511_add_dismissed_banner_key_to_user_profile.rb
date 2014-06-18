class AddDismissedBannerKeyToUserProfile < ActiveRecord::Migration
  def change
    add_column :user_profiles, :dismissed_banner_key, :integer, nullable: true
  end
end
