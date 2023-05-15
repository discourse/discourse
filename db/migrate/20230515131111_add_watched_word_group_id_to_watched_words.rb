# frozen_string_literal: true

class AddWatchedWordGroupIdToWatchedWords < ActiveRecord::Migration[7.0]
  def change
    add_column :watched_words, :watched_word_group_id, :bigint
    add_index :watched_words, :watched_word_group_id
  end
end
