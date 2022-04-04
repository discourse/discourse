# frozen_string_literal: true

class CopyThemeSettingsUploadsToUploadReferences < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL
      INSERT INTO upload_references(upload_id, target_type, target_id, created_at, updated_at)
      SELECT value::int, 'ThemeSetting', id, created_at, updated_at
      FROM theme_settings
      WHERE data_type = 6 AND value IS NOT NULL
      ON CONFLICT DO NOTHING
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
