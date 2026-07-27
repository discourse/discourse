# frozen_string_literal: true

class CopyNavigationMenuSiteSettingToThemes < ActiveRecord::Migration[8.0]
  def up
    return unless Migration::Helpers.existing_site?

    execute(<<~SQL)
      INSERT INTO theme_site_settings (name, data_type, value, theme_id, created_at, updated_at)
      SELECT site_setting.name, site_setting.data_type, site_setting.value, theme.id, NOW(), NOW()
      FROM site_settings AS site_setting
      CROSS JOIN themes AS theme
      WHERE site_setting.name = 'navigation_menu' AND NOT theme.component
      ON CONFLICT (name, theme_id) DO NOTHING
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
