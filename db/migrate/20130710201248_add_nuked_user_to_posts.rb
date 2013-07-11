class AddNukedUserToPosts < ActiveRecord::Migration
  def change
    add_column :posts, :nuked_user, :boolean, default: false
  end
end
