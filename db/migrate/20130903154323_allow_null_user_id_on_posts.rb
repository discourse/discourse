class AllowNullUserIdOnPosts < ActiveRecord::Migration
  def up
    change_column :posts, :user_id, :integer, null: true
    execute "UPDATE posts SET user_id = NULL WHERE nuked_user = true"
    remove_column :posts, :nuked_user
  end

  def down
    add_column    :posts, :nuked_user, :boolean, default: false
    change_column :posts, :user_id, :integer, null: false
  end
end
