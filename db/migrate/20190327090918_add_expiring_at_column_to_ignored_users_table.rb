# frozen_string_literal: true

class AddExpiringAtColumnToIgnoredUsersTable < ActiveRecord::Migration[5.2]
  def change
    add_column :ignored_users, :expiring_at, :datetime
  end
end
