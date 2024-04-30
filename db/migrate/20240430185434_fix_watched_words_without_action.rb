# frozen_string_literal: true

class FixWatchedWordsWithoutAction < ActiveRecord::Migration[7.0]
  def up
    # Set "censor" action to watched words without replacement
    execute <<~SQL
      UPDATE watched_words
      SET action = 2
      WHERE action = 0
      AND LENGTH(COALESCE(replacement, '')) = 0
    SQL

    # Set "replace" action to watched words with replacement
    execute <<~SQL
      UPDATE watched_words
      SET action = 5
      WHERE action = 0
    SQL

    # Update watched word groups with matching action
    execute <<~SQL
      UPDATE watched_word_groups
      SET action = ww.action
      FROM watched_words ww
      WHERE ww.watched_word_group_id = watched_word_groups.id
      AND ww.action != 0
      AND watched_word_groups.action = 0
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
