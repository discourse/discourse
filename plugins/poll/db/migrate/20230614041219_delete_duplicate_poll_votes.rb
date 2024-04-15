# frozen_string_literal: true

class DeleteDuplicatePollVotes < ActiveRecord::Migration[7.0]
  def up
    execute <<~SQL
    DELETE FROM poll_votes
    WHERE (poll_id, user_id, poll_option_id) IN (
      SELECT pv.poll_id, pv.user_id, pv.poll_option_id
      FROM poll_votes pv
      JOIN polls p ON pv.poll_id = p.id
      WHERE p.type = 0
      AND EXISTS (
        SELECT 1
        FROM poll_votes pv2
        WHERE pv.poll_id = pv2.poll_id
        AND pv.user_id = pv2.user_id
        AND pv.created_at < pv2.created_at
      )
    );
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
