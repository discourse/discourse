# frozen_string_literal: true

class ClearLastGravatarDownloadAttemptOnUserAvatars < ActiveRecord::Migration[6.0]
  def up
    execute <<~SQL
      UPDATE user_avatars
      SET last_gravatar_download_attempt = null
      WHERE user_id = -2 AND custom_upload_id IS NULL AND gravatar_upload_id IS NULL
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
