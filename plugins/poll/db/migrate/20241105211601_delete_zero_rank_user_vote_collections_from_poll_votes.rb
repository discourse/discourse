# frozen_string_literal: true
class DeleteZeroRankUserVoteCollectionsFromPollVotes < ActiveRecord::Migration[7.1]
  def up
    execute <<~SQL
    DELETE FROM poll_votes
      WHERE (poll_id, user_id) IN (
          SELECT poll_id, user_id
          FROM poll_votes
          GROUP BY poll_id, user_id
          HAVING SUM(rank) = 0
      );
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
