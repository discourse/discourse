# frozen_string_literal: true

class MoveChatUploadsToUploadReferences < ActiveRecord::Migration[7.0]
  def up
    execute <<~SQL
      INSERT INTO upload_references(upload_id, target_type, target_id, created_at, updated_at)
      SELECT chat_uploads.upload_id, 'ChatMessage', chat_uploads.chat_message_id, chat_uploads.created_at, chat_uploads.updated_at
      FROM chat_uploads
      INNER JOIN uploads ON uploads.id = chat_uploads.upload_id
      ON CONFLICT DO NOTHING
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
