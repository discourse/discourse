# frozen_string_literal: true

class RemoveNewPasswordStuffFromUser < ActiveRecord::Migration[4.2]
  def change
    remove_column :users, :new_password_hash
    remove_column :users, :new_salt
  end
end
