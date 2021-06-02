# frozen_string_literal: true

class MigrateWatchedWordsFromReplaceToLink < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL
      UPDATE watched_words
      SET action = 8
      WHERE action = 5 AND replacement ILIKE 'http%'
    SQL
  end

  def down
    execute("UPDATE watched_words SET action = 5 WHERE action = 8")
  end
end
