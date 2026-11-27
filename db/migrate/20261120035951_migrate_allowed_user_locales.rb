# frozen_string_literal: true

class MigrateAllowedUserLocales < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      INSERT INTO site_settings (name, value, data_type, created_at, updated_at)
      SELECT 'allowed_user_locales', CASE WHEN value = 't' THEN 'all' ELSE '' END, 8, created_at, updated_at
      FROM site_settings
      WHERE name = 'allow_user_locale'
      ON CONFLICT (name) DO NOTHING
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
