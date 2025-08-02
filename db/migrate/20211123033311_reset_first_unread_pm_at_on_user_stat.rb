# frozen_string_literal: true

class ResetFirstUnreadPmAtOnUserStat < ActiveRecord::Migration[6.1]
  def up
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
