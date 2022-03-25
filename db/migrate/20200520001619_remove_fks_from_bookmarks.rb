# frozen_string_literal: true

class RemoveFksFromBookmarks < ActiveRecord::Migration[6.0]
  def change
    remove_foreign_key(:bookmarks, :topics) if foreign_key_exists?(:bookmarks, :topics)
    remove_foreign_key(:bookmarks, :users) if foreign_key_exists?(:bookmarks, :users)
    remove_foreign_key(:bookmarks, :posts) if foreign_key_exists?(:bookmarks, :posts)
  end
end
