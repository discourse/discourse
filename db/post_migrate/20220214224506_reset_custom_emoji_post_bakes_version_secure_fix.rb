# frozen_string_literal: true

class ResetCustomEmojiPostBakesVersionSecureFix < ActiveRecord::Migration[6.1]
  def up
    if SiteSetting.secure_media
      execute <<~SQL
        UPDATE posts SET baked_version = 0
        WHERE cooked LIKE '%emoji emoji-custom%' AND cooked LIKE '%secure-media-uploads%'
      SQL
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
