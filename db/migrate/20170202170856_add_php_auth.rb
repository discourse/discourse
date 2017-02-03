class AddPhpAuth < ActiveRecord::Migration
  def change
    add_column :users, :php_password, :string
    add_column :users, :php_salt, :string
  end
end
