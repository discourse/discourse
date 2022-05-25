# frozen_string_literal: true

class CopyGroupsUploadsToUploadReferences < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL
      INSERT INTO upload_references(upload_id, target_type, target_id, created_at, updated_at)
      SELECT groups.flair_upload_id, 'Group', groups.id, uploads.created_at, uploads.updated_at
      FROM groups
      JOIN uploads ON uploads.id = groups.flair_upload_id
      WHERE groups.flair_upload_id IS NOT NULL
      ON CONFLICT DO NOTHING
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
