class AddAvatarUrlToFacebookInfo < ActiveRecord::Migration
  def change
    add_column :facebook_user_infos, :avatar_url, :string
  end
end
