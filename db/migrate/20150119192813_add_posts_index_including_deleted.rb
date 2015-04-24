class AddPostsIndexIncludingDeleted < ActiveRecord::Migration
  def change
    add_index :posts, [:user_id, :created_at]
  end
end
