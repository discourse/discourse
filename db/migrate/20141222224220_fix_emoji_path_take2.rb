class FixEmojiPathTake2 < ActiveRecord::Migration[4.2]
  OLD_URL = '/plugins/emoji/images/'
  NEW_URL = '/images/emoji/'

  def up
    execute <<-SQL
      UPDATE posts
         SET cooked = REPLACE(cooked, '#{OLD_URL}', '#{NEW_URL}')
       WHERE cooked LIKE '%#{OLD_URL}%'
    SQL
  end

  def down
    execute <<-SQL
      UPDATE posts
         SET cooked = REPLACE(cooked, '#{NEW_URL}', '#{OLD_URL}')
       WHERE cooked LIKE '%#{NEW_URL}%'
    SQL
  end
end
