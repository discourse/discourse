# frozen_string_literal: true

class CopyBadgesUploadsToUploadReferences < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL
      INSERT INTO upload_references(upload_id, target_type, target_id, created_at, updated_at)
      SELECT badges.image_upload_id, 'Badge', badges.id, uploads.created_at, uploads.updated_at
      FROM badges
      JOIN uploads ON uploads.id = badges.image_upload_id
      WHERE badges.image_upload_id IS NOT NULL
      ON CONFLICT DO NOTHING
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
