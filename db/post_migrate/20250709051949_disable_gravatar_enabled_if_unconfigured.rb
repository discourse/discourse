# frozen_string_literal: true

class DisableGravatarEnabledIfUnconfigured < ActiveRecord::Migration[7.2]
  def up
    execute <<~SQL
      INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
      SELECT 'gravatar_enabled', 5, 'f', 'NOW()', 'NOW()'
      WHERE EXISTS (
        SELECT 1
        FROM site_settings
        WHERE name = 'gravatar_base_url' AND (
          VALUE = '' OR
          VALUE IS NULL
        )
        LIMIT 1
      )
      ON CONFLICT DO NOTHING;
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
