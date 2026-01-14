# frozen_string_literal: true

class CreateSubscriptionsCustomers < ActiveRecord::Migration[6.0]
  def change
    create_table :discourse_subscriptions_customers do |t|
      t.string :customer_id, null: false, index: true
      t.string :product_id
      t.references :user
      t.timestamps
    end
  end
end
