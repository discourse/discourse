# frozen_string_literal: true
class RemoveOldReviewableClaimedTopics < ActiveRecord::Migration[7.2]
  def up
    execute <<~SQL
      DELETE FROM reviewable_claimed_topics
      WHERE created_at < NOW() - INTERVAL '1 hour'
      AND automatic = true
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
