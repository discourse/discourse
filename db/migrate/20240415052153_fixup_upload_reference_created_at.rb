# frozen_string_literal: true

class FixupUploadReferenceCreatedAt < ActiveRecord::Migration[7.0]
  def up
    ActiveRecord::Base.transaction do
      # Target: Post
      execute <<~SQL
        UPDATE upload_references
        SET created_at = posts.created_at, updated_at = NOW()
        FROM posts, uploads
        WHERE upload_references.target_id = posts.id
          AND upload_references.target_type = 'Post'
          AND upload_references.upload_id = uploads.id
          AND upload_references.created_at = uploads.created_at
      SQL

      # Target: UserExport
      execute <<~SQL
        UPDATE upload_references
        SET created_at = user_exports.created_at, updated_at = NOW()
        FROM user_exports, uploads
        WHERE upload_references.target_id = user_exports.id
          AND upload_references.target_type = 'UserExport'
          AND upload_references.upload_id = uploads.id
          AND upload_references.created_at = uploads.created_at
      SQL

      # Target: UserAvatar
      execute <<~SQL
        UPDATE upload_references
        SET created_at = user_avatars.updated_at, updated_at = NOW()
        FROM user_avatars, uploads
        WHERE upload_references.target_id = user_avatars.id
          AND upload_references.target_type = 'UserAvatar'
          AND upload_references.upload_id = uploads.id
          AND upload_references.created_at = uploads.created_at
      SQL

      # Target: CustomEmoji
      execute <<~SQL
        UPDATE upload_references
        SET created_at = custom_emojis.created_at, updated_at = NOW()
        FROM custom_emojis, uploads
        WHERE upload_references.target_id = custom_emojis.id
          AND upload_references.target_type = 'CustomEmoji'
          AND upload_references.upload_id = uploads.id
          AND upload_references.created_at = uploads.created_at
      SQL

      # Target: ThemeSetting
      execute <<~SQL
        UPDATE upload_references
        SET created_at = theme_settings.created_at, updated_at = NOW()
        FROM theme_settings, uploads
        WHERE upload_references.target_id = theme_settings.id
          AND upload_references.target_type = 'ThemeSetting'
          AND upload_references.upload_id = uploads.id
          AND upload_references.created_at = uploads.created_at
      SQL

      # Target: SiteSetting
      execute <<~SQL
        UPDATE upload_references
        SET created_at = site_settings.updated_at, updated_at = NOW()
        FROM site_settings, uploads
        WHERE upload_references.target_id = site_settings.id
          AND upload_references.target_type = 'SiteSetting'
          AND upload_references.upload_id = uploads.id
          AND upload_references.created_at = uploads.created_at
      SQL
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
