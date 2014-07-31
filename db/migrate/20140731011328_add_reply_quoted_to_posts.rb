class AddReplyQuotedToPosts < ActiveRecord::Migration
  def up
    add_column :posts, :reply_quoted, :boolean, null: false, default: false
    execute "UPDATE posts p
             SET reply_quoted = true
             WHERE EXISTS(
               SELECT 1 FROM quoted_posts q
               JOIN posts p1 ON p1.post_number = p.reply_to_post_number AND p1.topic_id = p.topic_id
               WHERE q.post_id = p.id AND q.quoted_post_id = p1.id
             ) AND p.reply_to_post_number IS NOT NULL"
  end

  def down
    remove_column :posts, :reply_quoted
  end
end
