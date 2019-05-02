# frozen_string_literal: true

class FixEmojiPath < ActiveRecord::Migration[4.2]
  BASE_URL = '/plugins/emoji/images/'

  def up
    execute <<-SQL
      UPDATE posts
         SET cooked = REPLACE(cooked, '#{BASE_URL}', '#{BASE_URL}emoji_one/')
       WHERE cooked LIKE '%#{BASE_URL}%'
    SQL
  end

  def down
    execute <<-SQL
      UPDATE posts
         SET cooked = REPLACE(cooked, '#{BASE_URL}emoji_one/', '#{BASE_URL}')
       WHERE cooked LIKE '%#{BASE_URL}emoji_one/%'
    SQL
  end
end
