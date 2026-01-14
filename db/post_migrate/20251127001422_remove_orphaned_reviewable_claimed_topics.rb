# frozen_string_literal: true

class RemoveOrphanedReviewableClaimedTopics < ActiveRecord::Migration[8.0]
  def up
    DB.exec(<<~SQL)
      DELETE FROM reviewable_claimed_topics
      WHERE user_id NOT IN (SELECT id FROM users)
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
