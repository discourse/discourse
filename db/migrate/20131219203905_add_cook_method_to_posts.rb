class AddCookMethodToPosts < ActiveRecord::Migration
  def change
    add_column :posts, :cook_method, :integer, default: 1, null: false
  end
end
