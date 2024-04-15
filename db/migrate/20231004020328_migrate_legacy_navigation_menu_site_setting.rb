# frozen_string_literal: true

class MigrateLegacyNavigationMenuSiteSetting < ActiveRecord::Migration[7.0]
  def up
    execute "UPDATE site_settings SET value = 'header dropdown' WHERE name = 'navigation_menu' AND value = 'legacy'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
