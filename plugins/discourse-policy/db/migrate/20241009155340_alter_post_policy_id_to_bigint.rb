# frozen_string_literal: true

class AlterPostPolicyIdToBigint < ActiveRecord::Migration[7.1]
  def up
    change_column :policy_users, :post_policy_id, :bigint
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
