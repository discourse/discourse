# frozen_string_literal: true

class CopyThemeFieldsUploadsToUploadReferences < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL
      INSERT INTO upload_references(upload_id, target_type, target_id, created_at, updated_at)
      SELECT theme_fields.upload_id, 'ThemeField', theme_fields.id, uploads.created_at, uploads.updated_at
      FROM theme_fields
      JOIN uploads ON uploads.id = theme_fields.upload_id
      WHERE type_id = 2
      ON CONFLICT DO NOTHING
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
