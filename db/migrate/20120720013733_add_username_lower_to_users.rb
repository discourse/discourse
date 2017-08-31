class AddUsernameLowerToUsers < ActiveRecord::Migration[4.2]
  def up
    add_column :users, :username_lower, :string, limit: 20
    execute "update users set username_lower = lower(username)"
    add_index :users, [:username_lower], unique: true
    change_column :users, :username_lower, :string, limit: 20, null: false
  end
  def down
    remove_column :users, :username_lower
  end
end
