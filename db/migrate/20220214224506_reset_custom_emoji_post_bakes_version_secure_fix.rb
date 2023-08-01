# frozen_string_literal: true

class ResetCustomEmojiPostBakesVersionSecureFix < ActiveRecord::Migration[6.1]
  def up
    secure_media_enabled =
      DB.query_single("SELECT value FROM site_settings WHERE name = 'secure_media'")

    execute <<~SQL if secure_media_enabled.present? && secure_media_enabled[0] == "t"
        UPDATE posts SET baked_version = 0
        WHERE cooked LIKE '%emoji emoji-custom%' AND cooked LIKE '%secure-media-uploads%'
      SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
