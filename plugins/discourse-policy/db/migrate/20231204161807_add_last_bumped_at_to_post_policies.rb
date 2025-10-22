# frozen_string_literal: true

class AddLastBumpedAtToPostPolicies < ActiveRecord::Migration[7.0]
  def change
    add_column :post_policies, :last_bumped_at, :datetime
  end
end
