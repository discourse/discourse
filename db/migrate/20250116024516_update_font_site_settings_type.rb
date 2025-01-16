# frozen_string_literal: true
class UpdateFontSiteSettingsType < ActiveRecord::Migration[7.2]
  def up
    execute "UPDATE site_settings SET data_type=8 WHERE name IN('base_font', 'heading_font')"
  end

  def down
    execute "UPDATE site_settings SET data_type=7 WHERE name IN('base_font', 'heading_font')"
  end
end
