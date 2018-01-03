class AddAvatarUrlToFacebookInfo < ActiveRecord::Migration[4.2]
  def change
    add_column :facebook_user_infos, :avatar_url, :string
  end
end
