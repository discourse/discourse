# frozen_string_literal: true

class RemoveEnableNewUserProfileNavGroupsSiteSettings < ActiveRecord::Migration[7.0]
  def up
    execute "DELETE FROM site_settings WHERE name = 'enable_new_user_profile_nav_groups'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
