class AddCategoryIdToUserHistories < ActiveRecord::Migration
  def change
    add_column :user_histories, :category_id, :integer
    add_index :user_histories, :category_id
  end
end
