# frozen_string_literal: true

class RemoveFksFromBookmarks < ActiveRecord::Migration[6.0]
  def change
    remove_foreign_key :bookmarks, :topics
    remove_foreign_key :bookmarks, :posts
    remove_foreign_key :bookmarks, :users
  end
end
