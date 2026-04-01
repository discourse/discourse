# frozen_string_literal: true

class CreateGamificationLeaderboardScores < ActiveRecord::Migration[7.2]
  def change
    create_table :gamification_leaderboard_scores do |t|
      t.integer :leaderboard_id, null: false
      t.integer :user_id, null: false
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
  end
end
