# frozen_string_literal: true

class CopySiteSettingsUploadsToUploadReferences < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL
      WITH site_settings_uploads AS (
        SELECT id, raw_upload_id::integer AS upload_id
        FROM (
          SELECT id, unnest(string_to_array(value, '|')) AS raw_upload_id
          FROM site_settings
          WHERE data_type = 17
        ) raw
        WHERE raw_upload_id ~ '^\d+$'
        UNION
        SELECT id, value::integer
        FROM site_settings
        WHERE data_type = 18 AND value != ''
      )
      INSERT INTO upload_references(upload_id, target_type, target_id, created_at, updated_at)
      SELECT site_settings_uploads.upload_id, 'SiteSetting', site_settings_uploads.id, uploads.created_at, uploads.updated_at
      FROM site_settings_uploads
      JOIN uploads ON uploads.id = site_settings_uploads.upload_id
      ON CONFLICT DO NOTHING
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
