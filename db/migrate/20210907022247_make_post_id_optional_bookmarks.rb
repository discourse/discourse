# frozen_string_literal: true

class MakePostIdOptionalBookmarks < ActiveRecord::Migration[6.1]
  def up
    remove_index :bookmarks, [:user_id, :post_id], unique: true
    add_index :bookmarks, [:user_id, :post_id, :topic_id], unique: true
  end

  def down
    Bookmark.where(post_id: -1).delete_all
    remove_index :bookmarks, [:user_id, :post_id, :topic_id], unique: true
    add_index :bookmarks, [:user_id, :post_id], unique: true
  end
end
