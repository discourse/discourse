# frozen_string_literal: true

class FixGroupAllowMembershipRequests < ActiveRecord::Migration[4.2]
  def up
    execute <<~SQL
    UPDATE groups g
    SET allow_membership_requests = 'f'
    WHERE NOT EXISTS (SELECT 1 FROM group_users gu WHERE gu.owner = 't' AND gu.group_id = g.id LIMIT 1)
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
