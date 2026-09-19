# frozen_string_literal: true
class DropSplashScreenSiteSetting < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      DELETE FROM site_settings
      WHERE name = 'splash_screen'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
