# frozen_string_literal: true

class AddAuthTokenToUsers < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :auth_token, :string, limit: 32
    add_index :users, [:auth_token]
  end
end
