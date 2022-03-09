# frozen_string_literal: true

class MovePostUploadsToUploadReferences < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL
      INSERT INTO upload_references(upload_id, target_type, target_id, created_at, updated_at)
      SELECT upload_id, 'Post', post_id, NOW(), NOW()
      FROM post_uploads
      ON CONFLICT DO NOTHING
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
