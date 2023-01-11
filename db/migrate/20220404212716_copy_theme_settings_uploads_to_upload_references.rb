# frozen_string_literal: true

class CopyThemeSettingsUploadsToUploadReferences < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL
      INSERT INTO upload_references(upload_id, target_type, target_id, created_at, updated_at)
      SELECT theme_settings.value::int, 'ThemeSetting', theme_settings.id, uploads.created_at, uploads.updated_at
      FROM theme_settings
      JOIN uploads ON uploads.id = theme_settings.value::int
      WHERE data_type = 6 AND theme_settings.value IS NOT NULL AND theme_settings.value != ''
      ON CONFLICT DO NOTHING
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
