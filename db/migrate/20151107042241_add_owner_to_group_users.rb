class AddOwnerToGroupUsers < ActiveRecord::Migration[4.2]
  def change
    add_column :group_users, :owner, :boolean, null: false, default: false
  end
end
