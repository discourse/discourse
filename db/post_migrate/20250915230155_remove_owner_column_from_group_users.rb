# frozen_string_literal: true

class RemoveOwnerColumnFromGroupUsers < ActiveRecord::Migration[8.0]
  def up
    remove_column :group_users, :owner
  end

  def down
    add_column :group_users, :owner, :boolean, null: false, default: false
  end
end