# frozen_string_literal: true

class RemoveInvalidWebsites < ActiveRecord::Migration[4.2]
  def change
    execute "UPDATE user_profiles SET website = NULL WHERE website = 'http://'"
  end
end
