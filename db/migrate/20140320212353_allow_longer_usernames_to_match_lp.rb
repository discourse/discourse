class AllowLongerUsernamesToMatchLp < ActiveRecord::Migration
  def change
    change_column :users, :username, :string, limit: 50, null: false
    change_column :users, :username_lower, :string, limit: 50, null: false
  end
end
