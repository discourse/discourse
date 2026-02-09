# frozen_string_literal: true
class CleanupUnlistedTopicHotScores < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      DELETE FROM topic_hot_scores
      WHERE topic_id IN (
        SELECT id FROM topics WHERE visible = false
      )
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
