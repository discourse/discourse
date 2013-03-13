class AddUserDeletedToPosts < ActiveRecord::Migration
  def change
    add_column :posts, :user_deleted, :boolean, null: false, default: false
  end
end
