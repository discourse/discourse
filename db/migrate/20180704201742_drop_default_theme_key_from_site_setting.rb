class DropDefaultThemeKeyFromSiteSetting < ActiveRecord::Migration[5.2]
  def up
    # preserve the current default theme by copying its ID to the new site setting...
    execute("INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
      SELECT 'default_theme_id', 3, id, now(), now()
        FROM themes
      WHERE key = (SELECT value FROM site_settings WHERE name = 'default_theme_key')")

    execute("DELETE FROM site_settings WHERE name = 'default_theme_key'")
  end

  def down
    execute("INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
      SELECT 'default_theme_key', 1, key, now(), now()
        FROM themes
      WHERE id = (SELECT value FROM site_settings WHERE name = 'default_theme_id')::integer")

    execute("DELETE FROM site_settings WHERE name = 'default_theme_id'")
  end
end
