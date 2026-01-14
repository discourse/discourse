# frozen_string_literal: true
class AddAddUsersToGroupToPostPolicy < ActiveRecord::Migration[7.2]
  def change
    add_column :post_policies, :add_users_to_group, :integer, null: true
  end
end
