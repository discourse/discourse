# frozen_string_literal: true

class AlterCustomerIdToBigint < ActiveRecord::Migration[7.1]
  def up
    change_column :discourse_subscriptions_subscriptions, :customer_id, :bigint
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
