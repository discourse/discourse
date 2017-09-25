class RemoveReplyBelowPostNumberFromPosts < ActiveRecord::Migration[4.2]
  def change
    remove_column :posts, :reply_below_post_number
  end
end
