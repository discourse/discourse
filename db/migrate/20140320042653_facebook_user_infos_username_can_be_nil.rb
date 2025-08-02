# frozen_string_literal: true

class FacebookUserInfosUsernameCanBeNil < ActiveRecord::Migration[4.2]
  def change
    change_column "facebook_user_infos", :username, :string, null: true
  end
end
