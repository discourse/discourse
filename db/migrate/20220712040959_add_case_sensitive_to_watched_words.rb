# frozen_string_literal: true

class AddCaseSensitiveToWatchedWords < ActiveRecord::Migration[7.0]
  def change
    add_column :watched_words, :case_sensitive, :boolean, default: false, null: false
  end
end
