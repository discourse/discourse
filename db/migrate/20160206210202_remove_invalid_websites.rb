class RemoveInvalidWebsites < ActiveRecord::Migration
  def change
    execute "UPDATE user_profiles SET website = NULL WHERE website = 'http://'"
  end
end
