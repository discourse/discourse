# frozen_string_literal: true

class CopyUserUploadsToUploadReferences < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL
      INSERT INTO upload_references(upload_id, target_type, target_id, created_at, updated_at)
      SELECT users.uploaded_avatar_id, 'User', users.id, uploads.created_at, uploads.updated_at
      FROM users
      JOIN uploads ON uploads.id = users.uploaded_avatar_id
      WHERE users.uploaded_avatar_id IS NOT NULL
      ON CONFLICT DO NOTHING
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
