# frozen_string_literal: true

class AddIndexReviewableScoresOnReviewableScoreType < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    execute <<~SQL
      DROP INDEX IF EXISTS index_reviewable_scores_on_reviewable_score_type;
    SQL

    execute <<~SQL
      CREATE INDEX CONCURRENTLY index_reviewable_scores_on_reviewable_score_type ON reviewable_scores (reviewable_score_type);
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
