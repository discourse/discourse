# frozen_string_literal: true

class CopyUserProfilesUploadsToUploadReferences < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL
      INSERT INTO upload_references(upload_id, target_type, target_id, created_at, updated_at)
      SELECT user_profiles.profile_background_upload_id, 'UserProfile', user_profiles.user_id, uploads.created_at, uploads.updated_at
      FROM user_profiles
      JOIN uploads ON uploads.id = user_profiles.profile_background_upload_id
      WHERE user_profiles.profile_background_upload_id IS NOT NULL
      ON CONFLICT DO NOTHING
    SQL

    execute <<~SQL
      INSERT INTO upload_references(upload_id, target_type, target_id, created_at, updated_at)
      SELECT user_profiles.card_background_upload_id, 'UserProfile', user_profiles.user_id, uploads.created_at, uploads.updated_at
      FROM user_profiles
      JOIN uploads ON uploads.id = user_profiles.card_background_upload_id
      WHERE user_profiles.card_background_upload_id IS NOT NULL
      ON CONFLICT DO NOTHING
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
