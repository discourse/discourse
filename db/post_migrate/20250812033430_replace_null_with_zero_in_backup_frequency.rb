# frozen_string_literal: true
class ReplaceNullWithZeroInBackupFrequency < ActiveRecord::Migration[8.0]
  def change
    execute <<~SQL
      UPDATE site_settings
      SET value = 0
      WHERE name = 'backup_frequency'
      AND value IS NULL
    SQL
  end
end
