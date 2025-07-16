# frozen_string_literal: true
class BackfillThemeableSiteSettings < ActiveRecord::Migration[7.2]
  def up
    initial_themeable_site_settings = %w[enable_welcome_banner search_experience]

    initial_themeable_site_settings.each do |setting|
      db_data_type, db_value =
        DB.query_single("SELECT data_type, value FROM site_settings WHERE name = ?", setting)

      # If there is no value in the DB, it means the admin hasn't changed it from the default,
      # and theme site settings will just use the default value.
      next if db_value.nil?

      theme_ids = DB.query_single("SELECT id FROM themes WHERE NOT component")

      theme_ids.each do |theme_id|
        # ThemeSiteSetting has an identical schema to SiteSetting, so we can use the same values
        # and data types.
        DB.exec(
          "INSERT INTO theme_site_settings (name, data_type, value, theme_id, created_at, updated_at)
           VALUES (:setting, :data_type, :value, :theme_id, NOW(), NOW())
           ON CONFLICT (name, theme_id) DO NOTHING",
          setting:,
          data_type: db_data_type,
          value: db_value,
          theme_id:,
        )
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
