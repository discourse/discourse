# frozen_string_literal: true

class AddStatusToSubscriptions < ActiveRecord::Migration[7.0]
  def change
    add_column :discourse_subscriptions_subscriptions, :status, :string
  end
end
