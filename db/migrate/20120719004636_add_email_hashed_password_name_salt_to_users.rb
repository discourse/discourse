class AddEmailHashedPasswordNameSaltToUsers < ActiveRecord::Migration[4.2]
  def up
    add_column :users, :email, :string, limit: 256

    execute "update users set email= md5(random()::text) || 'domain.com'"

    change_column :users, :email, :string, limit: 256, null: false
    add_index :users, [:email], unique: true

    rename_column :users, :display_username, :name

    add_column :users, :password_hash, :string, limit: 64
    add_column :users, :salt, :string, limit: 32
    add_column :users, :active, :boolean
    add_column :users, :activation_key, :string, limit: 32

    add_column :user_open_ids, :active, :boolean, null: false

  end

  def down
    remove_column :users, :email
    remove_column :users, :password_hash
    remove_column :users, :salt
    rename_column :users, :name, :display_username
    remove_column :users, :active
    remove_column :users, :activation_key
    remove_column :user_open_ids, :active
  end
end
