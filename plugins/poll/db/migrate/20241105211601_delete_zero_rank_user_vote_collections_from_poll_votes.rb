# frozen_string_literal: true
class DeleteZeroRankUserVoteCollectionsFromPollVotes < ActiveRecord::Migration[7.1]
  def up
    execute <<~SQL
      DELETE FROM poll_votes
      WHERE (poll_id, user_id) IN (
          SELECT poll_votes.poll_id, poll_votes.user_id
          FROM poll_votes
          JOIN polls ON polls.id = poll_votes.poll_id
          WHERE polls.type = 3
          GROUP BY poll_votes.poll_id, poll_votes.user_id
          HAVING SUM(poll_votes.rank) = 0
      );
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
