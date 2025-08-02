# frozen_string_literal: true

class SetSecureUploadsSettingsBasedOnSecureMediaEquivalent < ActiveRecord::Migration[7.0]
  def up
    secure_media_enabled =
      DB.query_single("SELECT value FROM site_settings WHERE name = 'secure_media'")

    execute <<~SQL if secure_media_enabled.present? && secure_media_enabled[0] == "t"
      INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
      VALUES ('secure_uploads', 5, 't', now(), now())
      SQL

    secure_media_allow_embed_images_in_emails =
      DB.query_single(
        "SELECT value FROM site_settings WHERE name = 'secure_media_allow_embed_images_in_emails'",
      )

    if secure_media_allow_embed_images_in_emails.present? &&
         secure_media_allow_embed_images_in_emails[0] == "t"
      execute <<~SQL
      INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
      VALUES ('secure_uploads_allow_embed_images_in_emails', 5, 't', now(), now())
      SQL
    end

    secure_media_max_email_embed_image_size_kb =
      DB.query_single(
        "SELECT value FROM site_settings WHERE name = 'secure_media_max_email_embed_image_size_kb'",
      )

    execute <<~SQL if secure_media_max_email_embed_image_size_kb.present?
      INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
      VALUES ('secure_uploads_max_email_embed_image_size_kb', 3, '#{secure_media_max_email_embed_image_size_kb[0]}', now(), now())
      SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
