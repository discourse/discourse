# frozen_string_literal: true

class CreateProducts < ActiveRecord::Migration[6.0]
  def change
    create_table :discourse_subscriptions_products do |t|
      t.string :external_id, null: false, index: true

      t.timestamps
    end
  end
end
