class AddUserIdIndexToPosts < ActiveRecord::Migration[4.2]
  def change
    add_index :posts, :user_id
  end
end
