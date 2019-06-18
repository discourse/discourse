# frozen_string_literal: true

class AddUserIdGroupIdIndexToGroupUsers < ActiveRecord::Migration[4.2]
  def change
    add_index :group_users, [:user_id, :group_id], unique: true
  end
end
