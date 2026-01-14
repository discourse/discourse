# frozen_string_literal: true

class AddPrivateToPostPolicies < ActiveRecord::Migration[6.1]
  def up
    add_column :post_policies, :private, :boolean, default: false, null: false
  end

  def down
    remove_column :post_policies, :private
  end
end
