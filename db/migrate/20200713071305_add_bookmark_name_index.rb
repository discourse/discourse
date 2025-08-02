# frozen_string_literal: true

class AddBookmarkNameIndex < ActiveRecord::Migration[6.0]
  def change
    add_index :bookmarks, :name
  end
end
