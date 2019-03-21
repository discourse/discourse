class AddPostsIndexIncludingDeleted < ActiveRecord::Migration[4.2]
  def change
    add_index :posts, %i[user_id created_at]
  end
end
