class AddDisplayUsernameToUsers < ActiveRecord::Migration
  def up
    add_column :users, :display_username, :string
    execute "UPDATE users SET display_username = username"
    execute "UPDATE users SET username = REPLACE(username, ' ', '')"
    add_index :users, :username, unique: true
  end

  def down
    remove_index :users, :username
    execute "UPDATE users SET username = display_username"
    remove_column :users, :display_username
  end

end
