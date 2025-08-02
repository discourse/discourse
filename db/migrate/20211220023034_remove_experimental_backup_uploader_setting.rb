# frozen_string_literal: true

class RemoveExperimentalBackupUploaderSetting < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL
      DELETE FROM site_settings
      WHERE name = 'enable_experimental_backup_uploader'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
