# frozen_string_literal: true

class AddNotNullToIgnoredUsers < ActiveRecord::Migration[6.0]
  def up
    execute <<~SQL
      UPDATE ignored_users
      SET expiring_at = created_at + interval '4 months'
      WHERE expiring_at IS NULL
    SQL

    change_column_null :ignored_users, :expiring_at, false
  end

  def down
    change_column_null :ignored_users, :expiring_at, true
  end
end
