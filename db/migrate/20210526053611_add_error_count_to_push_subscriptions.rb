# frozen_string_literal: true

class AddErrorCountToPushSubscriptions < ActiveRecord::Migration[6.1]
  def change
    add_column :push_subscriptions, :error_count, :integer, null: false, default: 0
    add_column :push_subscriptions, :first_error_at, :datetime
  end
end
