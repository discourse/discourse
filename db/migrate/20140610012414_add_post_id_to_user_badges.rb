class AddPostIdToUserBadges < ActiveRecord::Migration
  def change
    add_column :user_badges, :post_id, :integer
  end
end
