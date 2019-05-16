# frozen_string_literal: true

class AddBookmarkCountToPosts < ActiveRecord::Migration[4.2]
  def change
    add_column :posts, :bookmark_count, :integer, default: 0, null: false
    add_column :forum_threads, :bookmark_count, :integer, default: 0, null: false
    add_column :forum_threads, :star_count, :integer, default: 0, null: false

    execute "UPDATE posts SET bookmark_count = (SELECT COUNT(*)
                                                FROM bookmarks
                                                WHERE post_number = posts.post_number AND forum_thread_id = posts.forum_thread_id)"

    execute "UPDATE forum_threads SET bookmark_count = (SELECT COUNT(*)
                                                        FROM bookmarks
                                                        WHERE forum_thread_id = forum_threads.id)"

    execute "UPDATE forum_threads SET star_count = (SELECT COUNT(*)
                                                        FROM forum_thread_users
                                                        WHERE forum_thread_id = forum_threads.id AND starred = true)"
  end
end
