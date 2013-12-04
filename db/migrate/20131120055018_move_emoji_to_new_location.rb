class MoveEmojiToNewLocation < ActiveRecord::Migration
  def up
    execute("update posts set cooked = regexp_replace(cooked, '\(<img[^\>]*)assets\/emoji\/', '\\1plugins\/emoji\/images\/' , 'g') where cooked like '%emoji%'")
  end

  def down
    execute("update posts set cooked = regexp_replace(cooked, '\(<img[^\>]*)plugins\/emoji\/images\/', '\\1assets\/emoji\/' , 'g') where cooked like '%emoji%'")
  end
end
