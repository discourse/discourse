class AddAuthTokenToUsers < ActiveRecord::Migration
  def change
    add_column :users, :auth_token, :string, limit: 32
    add_index :users, [:auth_token]
  end
end
