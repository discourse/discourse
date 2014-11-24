class AddCategoryModerators < ActiveRecord::Migration
  def change
    add_column :category_users, :moderator, :boolean, null: false, default: false
  end
end
