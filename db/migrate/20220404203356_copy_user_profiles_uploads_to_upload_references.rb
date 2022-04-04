# frozen_string_literal: true

class CopyUserProfilesUploadsToUploadReferences < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL
      INSERT INTO upload_references(upload_id, target_type, target_id, created_at, updated_at)
      SELECT profile_background_upload_id, 'UserProfile', user_id, NOW(), NOW()
      FROM user_profiles
      WHERE profile_background_upload_id IS NOT NULL
      ON CONFLICT DO NOTHING
    SQL

    execute <<~SQL
      INSERT INTO upload_references(upload_id, target_type, target_id, created_at, updated_at)
      SELECT card_background_upload_id, 'UserProfile', user_id, NOW(), NOW()
      FROM user_profiles
      WHERE card_background_upload_id IS NOT NULL
      ON CONFLICT DO NOTHING
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
