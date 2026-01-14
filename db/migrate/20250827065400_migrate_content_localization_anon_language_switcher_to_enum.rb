# frozen_string_literal: true

class MigrateContentLocalizationAnonLanguageSwitcherToEnum < ActiveRecord::Migration[7.1]
  def up
    from_value = "content_localization_anon_language_switcher"
    to_value = "content_localization_language_switcher"

    if DB.query_single("SELECT 1 FROM site_settings WHERE name = '#{from_value}'").first
      execute <<~SQL
        UPDATE site_settings
        SET name = '#{to_value}',
            value = CASE
              WHEN value = 'f' THEN 'none'
              WHEN value = 't' THEN 'anonymous'
              ELSE 'none'
            END,
            data_type = 7
        WHERE name = '#{from_value}'
          AND NOT EXISTS (
            SELECT 1 FROM site_settings
            WHERE name = '#{to_value}'
          )
      SQL
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
