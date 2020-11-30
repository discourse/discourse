# frozen_string_literal: true

class RemoveUnneccessaryBookmarkNameIndex < ActiveRecord::Migration[6.0]
  def change
    remove_index :bookmarks, :name
  end
end
