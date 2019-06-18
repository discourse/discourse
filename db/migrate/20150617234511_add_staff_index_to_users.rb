# frozen_string_literal: true

class AddStaffIndexToUsers < ActiveRecord::Migration[4.2]
  def change
    add_index :users, [:id], name: 'idx_users_admin', where: 'admin'
    add_index :users, [:id], name: 'idx_users_moderator', where: 'moderator'
  end
end
