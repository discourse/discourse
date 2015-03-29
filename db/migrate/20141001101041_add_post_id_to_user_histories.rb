class AddPostIdToUserHistories < ActiveRecord::Migration
  def change
    add_column :user_histories, :post_id, :integer
  end
end
