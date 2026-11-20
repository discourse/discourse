# frozen_string_literal: true

class MigrateAllowedUserLocales < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
      SELECT 'allowed_user_locales', 8, 'none', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM site_settings
      WHERE name = 'allow_user_locale' AND data_type = 5 AND value = 'f'
      ON CONFLICT (name) DO NOTHING
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
