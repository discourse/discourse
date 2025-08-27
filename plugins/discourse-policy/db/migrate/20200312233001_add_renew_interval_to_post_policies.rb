# frozen_string_literal: true

class AddRenewIntervalToPostPolicies < ActiveRecord::Migration[6.0]
  def up
    add_column :post_policies, :renew_interval, :integer
  end

  def down
    remove_column :post_policies, :renew_interval
  end
end
