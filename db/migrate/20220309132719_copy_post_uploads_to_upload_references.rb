# frozen_string_literal: true

class CopyPostUploadsToUploadReferences < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL
      INSERT INTO upload_references(upload_id, target_type, target_id, created_at, updated_at)
      SELECT post_uploads.upload_id, 'Post', post_uploads.post_id, uploads.created_at, uploads.updated_at
      FROM post_uploads
      JOIN uploads ON uploads.id = post_uploads.upload_id
      ON CONFLICT DO NOTHING
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
