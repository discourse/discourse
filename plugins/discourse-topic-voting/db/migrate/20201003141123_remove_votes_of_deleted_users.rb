# frozen_string_literal: true

class RemoveVotesOfDeletedUsers < ActiveRecord::Migration[6.0]
  def up
    DB.exec <<~SQL
      DELETE FROM discourse_voting_votes
      WHERE user_id IN (
        SELECT votes.user_id
        FROM discourse_voting_votes votes
        LEFT JOIN users ON users.id = votes.user_id
        WHERE users.id IS NULL
      )
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
