# frozen_string_literal: true

class AddFirstUnreadPmAToGroupUser < ActiveRecord::Migration[6.0]
  def up
    add_column :group_users,
               :first_unread_pm_at,
               :datetime,
               null: false,
               default: -> { "CURRENT_TIMESTAMP" }

    execute <<~SQL
    UPDATE group_users gu
    SET first_unread_pm_at = gu.created_at
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
