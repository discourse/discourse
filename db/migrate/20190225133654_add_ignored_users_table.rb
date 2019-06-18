# frozen_string_literal: true

class AddIgnoredUsersTable < ActiveRecord::Migration[5.2]
  def change
    create_table :ignored_users do |t|
      t.integer :user_id, null: false
      t.integer :ignored_user_id, null: false
      t.timestamps null: false
    end

    add_index :ignored_users, [:user_id, :ignored_user_id], unique: true
    add_index :ignored_users, [:ignored_user_id, :user_id], unique: true
  end
end
