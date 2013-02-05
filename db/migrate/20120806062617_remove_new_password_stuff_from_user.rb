class RemoveNewPasswordStuffFromUser < ActiveRecord::Migration
  def change
    remove_column :users, :new_password_hash
    remove_column :users, :new_salt
  end
end
