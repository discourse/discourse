# frozen_string_literal: true

class RemoveIgnoreUserEnabledSiteSetting < ActiveRecord::Migration[5.2]
  def up
    execute "DELETE FROM site_settings WHERE name = 'ignore_user_enabled'"
  end

  def down
  end
end
