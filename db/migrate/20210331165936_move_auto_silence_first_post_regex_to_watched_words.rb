# frozen_string_literal: true

class MoveAutoSilenceFirstPostRegexToWatchedWords < ActiveRecord::Migration[6.0]
  def up
    execute <<~SQL
      INSERT INTO watched_words (word, action, first_post_only, created_at, updated_at)
      SELECT value, 3, true, created_at, updated_at
      FROM site_settings
      WHERE name = 'auto_silence_first_post_regex'
    SQL

    execute "DELETE FROM site_settings WHERE name = 'auto_silence_first_post_regex'"
  end

  def down
    execute <<~SQL
      INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
      SELECT 'auto_silence_first_post_regex', 3, word, created_at, updated_at
      FROM watched_words
      WHERE action = 3 AND first_post_only
      LIMIT 1
    SQL

    execute "DELETE FROM watched_words WHERE action = 3 AND first_post_only"
  end
end
