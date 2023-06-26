# frozen_string_literal: true

class DeleteDuplicatePollVotes < ActiveRecord::Migration[7.0]
  def up
    execute <<~SQL
      DELETE FROM poll_votes
      WHERE (poll_id, user_id, updated_at) NOT IN (
        SELECT poll_id, user_id, MAX(updated_at)
        FROM poll_votes
        GROUP BY poll_id, user_id
      )
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
