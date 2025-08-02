# frozen_string_literal: true

class CopyCustomEmojisUploadsToUploadReferences < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL
      INSERT INTO upload_references(upload_id, target_type, target_id, created_at, updated_at)
      SELECT custom_emojis.upload_id, 'CustomEmoji', custom_emojis.id, uploads.created_at, uploads.updated_at
      FROM custom_emojis
      JOIN uploads ON uploads.id = custom_emojis.upload_id
      WHERE custom_emojis.upload_id IS NOT NULL
      ON CONFLICT DO NOTHING
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
