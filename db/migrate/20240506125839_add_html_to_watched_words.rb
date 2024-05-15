# frozen_string_literal: true

class AddHtmlToWatchedWords < ActiveRecord::Migration[7.0]
  def change
    add_column :watched_words, :html, :boolean, default: false, null: false
  end
end
