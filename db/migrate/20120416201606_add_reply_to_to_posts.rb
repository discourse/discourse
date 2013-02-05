class AddReplyToToPosts < ActiveRecord::Migration
  def change
    add_column :posts, :reply_to_post_number, :integer, null: true
    add_index :posts, :reply_to_post_number
  end
end
