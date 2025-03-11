# frozen_string_literal: true
class RemoveOldAdminSidebarEnabledGroupsSiteSettings < ActiveRecord::Migration[7.2]
  def up
    execute "DELETE FROM site_settings WHERE name = 'admin_sidebar_enabled_groups'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
