# frozen_string_literal: true

class CopyUserAvatarsUploadsToUploadReferences < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL
      INSERT INTO upload_references(upload_id, target_type, target_id, created_at, updated_at)
      SELECT user_avatars.custom_upload_id, 'UserAvatar', user_avatars.id, uploads.created_at, uploads.updated_at
      FROM user_avatars
      JOIN uploads ON uploads.id = user_avatars.custom_upload_id
      WHERE user_avatars.custom_upload_id IS NOT NULL
      ON CONFLICT DO NOTHING
    SQL

    execute <<~SQL
      INSERT INTO upload_references(upload_id, target_type, target_id, created_at, updated_at)
      SELECT user_avatars.gravatar_upload_id, 'UserAvatar', user_avatars.id, uploads.created_at, uploads.updated_at
      FROM user_avatars
      JOIN uploads ON uploads.id = user_avatars.gravatar_upload_id
      WHERE user_avatars.gravatar_upload_id IS NOT NULL
      ON CONFLICT DO NOTHING
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
