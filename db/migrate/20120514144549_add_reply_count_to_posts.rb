# frozen_string_literal: true

class AddReplyCountToPosts < ActiveRecord::Migration[4.2]
  def up
    add_column :posts, :reply_count, :integer, null: false, default: 0

    execute "UPDATE posts
             SET reply_count = (SELECT count(*) FROM posts AS p2 WHERE p2.reply_to_post_number = posts.post_number)"
  end

  def down
    remove_column :posts, :reply_count
  end

end
