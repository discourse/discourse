class RemoveReplyBelowPostNumberFromPosts < ActiveRecord::Migration
  def change
    remove_column :posts, :reply_below_post_number
  end
end
