# frozen_string_literal: true

class DeleteDuplicatePollVotes < ActiveRecord::Migration[7.0]
  def up
    execute <<~SQL
      DELETE FROM poll_votes
      WHERE ctid NOT IN (
        SELECT MIN(ctid)
        FROM poll_votes
        GROUP BY poll_id, user_id, poll_option_id
      );
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
