# frozen_string_literal: true

class CopyUserAvatarsUploadsToUploadReferences < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL
      INSERT INTO upload_references(upload_id, target_type, target_id, created_at, updated_at)
      SELECT custom_upload_id, 'UserAvatar', id, created_at, updated_at
      FROM user_avatars
      WHERE custom_upload_id IS NOT NULL
      ON CONFLICT DO NOTHING
    SQL

    execute <<~SQL
      INSERT INTO upload_references(upload_id, target_type, target_id, created_at, updated_at)
      SELECT gravatar_upload_id, 'UserAvatar', id, created_at, updated_at
      FROM user_avatars
      WHERE gravatar_upload_id IS NOT NULL
      ON CONFLICT DO NOTHING
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
