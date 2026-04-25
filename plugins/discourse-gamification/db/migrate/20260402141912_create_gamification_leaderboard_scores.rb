# frozen_string_literal: true

class CreateGamificationLeaderboardScores < ActiveRecord::Migration[7.2]
  def up
    create_table :gamification_leaderboard_scores do |t|
      t.bigint :leaderboard_id, null: false
      t.bigint :user_id, null: false
      t.date :date, null: false
      t.integer :score, null: false, default: 0
    end

    add_index :gamification_leaderboard_scores,
              %i[leaderboard_id user_id date],
              unique: true,
              name: "idx_leaderboard_scores_lb_user_date"
    add_index :gamification_leaderboard_scores,
              %i[leaderboard_id date],
              name: "idx_leaderboard_scores_lb_date"

    # Backfill: copy existing global scores into per-leaderboard scores
    # for every existing leaderboard. All leaderboards used global settings
    # before this migration, so they all get identical copies.
    if table_exists?(:gamification_scores) && table_exists?(:gamification_leaderboards)
      leaderboard_ids = DB.query_single("SELECT id FROM gamification_leaderboards")
      leaderboard_ids.each { |lb_id| execute <<~SQL }
          INSERT INTO gamification_leaderboard_scores (leaderboard_id, user_id, date, score)
          SELECT #{lb_id}, gs.user_id, gs.date, gs.score
          FROM gamification_scores gs
        SQL
    end
  end

  def down
    drop_table :gamification_leaderboard_scores
  end
end
