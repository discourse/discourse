# frozen_string_literal: true

class MoveAutoSilenceFirstPostRegexToWatchedWords < ActiveRecord::Migration[6.0]
  def up
    execute <<~SQL
      INSERT INTO watched_words (word, action, created_at, updated_at)
      SELECT value, 5, created_at, updated_at
      FROM site_settings
      WHERE name = 'auto_silence_first_post_regex'
    SQL

    execute "DELETE FROM site_settings WHERE name = 'auto_silence_first_post_regex'"
  end

  def down
    execute <<~SQL
      INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
      SELECT 'auto_silence_first_post_regex', 1, word, created_at, updated_at
      FROM watched_words
      WHERE action = 5
      LIMIT 1
    SQL

    execute "DELETE FROM watched_words WHERE action = 5"
  end
end
