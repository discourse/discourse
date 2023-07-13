# frozen_string_literal: true

class RemoveEmojiOneFromEmojiSetSiteSetting < ActiveRecord::Migration[6.0]
  def up
    result = execute("SELECT value FROM site_settings WHERE name='emoji_set' and value='emoji_one'")
    return if result.count.zero?

    execute "DELETE FROM site_settings where name='emoji_set' and value='emoji_one'"
    execute "UPDATE posts SET baked_version = 0 WHERE cooked LIKE '%/images/emoji/emoji_one%'"
  end

  def down
    # Cannot undo
  end
end
