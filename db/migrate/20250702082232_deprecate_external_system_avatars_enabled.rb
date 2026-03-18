# frozen_string_literal: true
class DeprecateExternalSystemAvatarsEnabled < ActiveRecord::Migration[7.2]
  def up
    execute <<~SQL
      INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
      SELECT 'external_system_avatars_url', 1, '', 'NOW()', 'NOW()'
      WHERE EXISTS (
        SELECT 1
        FROM site_settings
        WHERE name = 'external_system_avatars_enabled'
        AND value = 'f'
      )
      ON CONFLICT(name) DO UPDATE
      SET value = EXCLUDED.value, updated_at = EXCLUDED.updated_at;
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
