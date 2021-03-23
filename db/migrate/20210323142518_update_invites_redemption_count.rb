# frozen_string_literal: true

class UpdateInvitesRedemptionCount < ActiveRecord::Migration[6.0]
  def change
    execute <<~SQL
      WITH invite_counts AS (
        SELECT invite_id, COUNT(*) count
        FROM invited_users
        GROUP BY invite_id
      )
      UPDATE invites
      SET redemption_count = GREATEST(redemption_count, count)
      FROM invite_counts
      WHERE invites.id = invite_counts.invite_id
    SQL
  end
end
