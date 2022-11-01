# frozen_string_literal: true

class RenameOnboardingPopupsSiteSetting < ActiveRecord::Migration[7.0]
  def up
    execute "UPDATE site_settings SET name = 'enable_user_tips' WHERE name = 'enable_user_tips'"
  end

  def down
    execute "UPDATE site_settings SET name = 'enable_user_tips' WHERE name = 'enable_user_tips'"
  end
end
