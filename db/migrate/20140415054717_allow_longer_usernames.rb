class AllowLongerUsernames < ActiveRecord::Migration
  def up
    change_column :users, :username, :string, limit: 60
    change_column :users, :username_lower, :string, limit: 60
  end

  def down
  end
end
