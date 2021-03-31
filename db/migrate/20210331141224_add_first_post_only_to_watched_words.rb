# frozen_string_literal: true

class AddFirstPostOnlyToWatchedWords < ActiveRecord::Migration[6.0]
  def change
    add_column :watched_words, :first_post_only, :boolean, default: false, null: false
  end
end
