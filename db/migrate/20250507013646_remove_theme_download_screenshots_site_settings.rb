# frozen_string_literal: true
class RemoveThemeDownloadScreenshotsSiteSettings < ActiveRecord::Migration[7.2]
  def up
    execute "DELETE FROM site_settings WHERE name = 'theme_download_screenshots'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
