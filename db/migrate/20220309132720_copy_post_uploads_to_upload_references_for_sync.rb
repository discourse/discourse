# frozen_string_literal: true

class CopyPostUploadsToUploadReferencesForSync < ActiveRecord::Migration[6.1]
  def up
    # Migrates any post uploads that might have been created between the first
    # migration and when the deploy process finished.
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
