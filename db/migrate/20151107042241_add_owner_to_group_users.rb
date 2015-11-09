class AddOwnerToGroupUsers < ActiveRecord::Migration
  def change
    add_column :group_users, :owner, :boolean, null: false, default: false
  end
end
