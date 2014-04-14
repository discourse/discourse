class FacebookUserInfosUsernameCanBeNil < ActiveRecord::Migration
  def change
    change_column "facebook_user_infos", :username, :string, null: true
  end
end
