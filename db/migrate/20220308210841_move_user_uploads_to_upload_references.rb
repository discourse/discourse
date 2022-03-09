# frozen_string_literal: true

class MoveUserUploadsToUploadReferences < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL
      INSERT INTO upload_references(upload_id, target_type, target_id, created_at, updated_at)
      SELECT upload_id, 'User', user_id, created_at, NOW()
      FROM user_uploads
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
