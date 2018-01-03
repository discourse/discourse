class AddReplyToUserIdToPost < ActiveRecord::Migration[4.2]
  def up
    # caching this column makes the topic page WAY faster
    add_column :posts, :reply_to_user_id, :integer
    execute 'UPDATE posts p SET reply_to_user_id = (
                SELECT u.id from users u
                JOIN posts p2 ON  p2.user_id = u.id AND
                                  p2.post_number = p.reply_to_post_number AND
                                  p2.topic_id = p.topic_id
            )'
  end

  def down
    remove_column :posts, :reply_to_user_id
  end
end
