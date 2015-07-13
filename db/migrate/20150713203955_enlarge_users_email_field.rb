class EnlargeUsersEmailField < ActiveRecord::Migration
  def up
    change_column :users, :email, :string, :limit => 513
  end
  def down
    change_column :users, :email, :string, :limit => 128
  end
end
