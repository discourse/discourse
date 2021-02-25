# frozen_string_literal: true

class MoveAutoSilenceFirstPostRegexToWatchedWords < ActiveRecord::Migration[6.0]
  def up
    execute <<~SQL
      INSERT INTO watched_words (word, action, created_at, updated_at)
      SELECT value, 3, created_at, updated_at
      FROM site_settings
      WHERE name = 'auto_silence_first_post_regex'
      ON CONFLICT DO NOTHING
    SQL

    execute <<~SQL
      INSERT INTO watched_words (word, action, created_at, updated_at)
      SELECT unnest(string_to_array(value, '|')), 3, created_at, updated_at
      FROM site_settings
      WHERE name = 'auto_silence_first_post_regex'
      ON CONFLICT DO NOTHING
    SQL
  end

  def down
  end
end
