# frozen_string_literal: true

class RemoveEnableCustomSplashScreenSiteSetting < ActiveRecord::Migration[8.0]
  def up
    execute "DELETE FROM site_settings WHERE name = 'enable_custom_splash_screen'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
