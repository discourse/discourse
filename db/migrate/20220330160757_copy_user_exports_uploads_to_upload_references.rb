# frozen_string_literal: true

class CopyUserExportsUploadsToUploadReferences < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL
      INSERT INTO upload_references(upload_id, target_type, target_id, created_at, updated_at)
      SELECT user_exports.upload_id, 'UserExport', user_exports.id, uploads.created_at, uploads.updated_at
      FROM user_exports
      JOIN uploads ON uploads.id = user_exports.upload_id
      ON CONFLICT DO NOTHING
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
