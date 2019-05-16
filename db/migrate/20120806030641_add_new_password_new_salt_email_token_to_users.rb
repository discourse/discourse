# frozen_string_literal: true

class AddNewPasswordNewSaltEmailTokenToUsers < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :new_salt, :string, limit: 32
    add_column :users, :new_password_hash, :string, limit: 64
    # email token is more flexible, can be used for both intial activation AND password change confirmation
    add_column :users, :email_token, :string, limit: 32
    remove_column :users, :activation_key
  end
end
