# frozen_string_literal: true

class AddReplacementToWatchedWords < ActiveRecord::Migration[6.0]
  def change
    add_column :watched_words, :replacement, :string, null: true
  end
end
