# frozen_string_literal: true

class EnforceUserProfileMaxLimits < ActiveRecord::Migration[7.0]
  def change
    execute "UPDATE user_profiles SET location = LEFT(location, 3000) WHERE location IS NOT NULL AND LENGTH(location) > 3000"
    execute "UPDATE user_profiles SET website = LEFT(website, 3000) WHERE website IS NOT NULL AND LENGTH(website) > 3000"

    change_column :user_profiles, :location, :string, limit: 3000
    change_column :user_profiles, :website, :string, limit: 3000
  end
end
