# frozen_string_literal: true

class MakePostIdOptionalBookmarks < ActiveRecord::Migration[6.1]
  def up
    remove_index :bookmarks, [:user_id, :post_id], unique: true
    change_column_null :bookmarks, :post_id, true
    add_index :bookmarks, [:user_id, :post_id, :topic_id], unique: true
  end

  def down
    Bookmark.where(post_id: -1).delete_all
    Bookmark.where(post_id: nil).delete_all
    remove_index :bookmarks, [:user_id, :post_id, :topic_id], unique: true
    change_column_null :bookmarks, :post_id, false
    add_index :bookmarks, [:user_id, :post_id], unique: true
  end
end
