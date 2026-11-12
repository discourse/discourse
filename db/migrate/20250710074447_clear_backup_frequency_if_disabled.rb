# frozen_string_literal: true

class ClearBackupFrequencyIfDisabled < ActiveRecord::Migration[7.2]
  def up
    execute <<~SQL
      INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
      SELECT 'backup_frequency', 3, NULL, 'NOW()', 'NOW()'
      WHERE EXISTS (
        SELECT 1
        FROM site_settings
        WHERE name = 'automatic_backups_enabled'
        AND VALUE = 'f'
        LIMIT 1
      )
      ON CONFLICT (name) DO UPDATE SET value = NULL, updated_at = 'NOW()';
    SQL

    execute <<~SQL
      DELETE FROM site_settings
      WHERE name = 'automatic_backups_enabled';
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
