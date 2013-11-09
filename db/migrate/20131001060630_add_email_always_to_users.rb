class AddEmailAlwaysToUsers < ActiveRecord::Migration
  def change
    add_column :users, :email_always, :bool, default: false, null: false
  end
end
