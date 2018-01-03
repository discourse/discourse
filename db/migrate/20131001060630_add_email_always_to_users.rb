class AddEmailAlwaysToUsers < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :email_always, :bool, default: false, null: false
  end
end
