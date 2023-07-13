# frozen_string_literal: true

class AddFirstUnreadPmAtToUserStats < ActiveRecord::Migration[6.0]
  def up
    add_column :user_stats,
               :first_unread_pm_at,
               :datetime,
               null: false,
               default: -> { "CURRENT_TIMESTAMP" }

    execute <<~SQL
    UPDATE user_stats us
    SET first_unread_pm_at = u.created_at
    FROM users u
    WHERE u.id = us.user_id
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
