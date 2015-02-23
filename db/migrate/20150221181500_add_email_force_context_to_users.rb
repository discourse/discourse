class AddEmailForceContextToUsers < ActiveRecord::Migration
  def change
    add_column :users, :email_force_context, :boolean, default: false, null: false
  end
end
