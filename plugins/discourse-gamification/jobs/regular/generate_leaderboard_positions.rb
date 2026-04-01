# frozen_string_literal: true

module Jobs
  class GenerateLeaderboardPositions < ::Jobs::Base
    def execute(args)
      leaderboard_id = args[:leaderboard_id]
      raise Discourse::InvalidParameters.new(:leaderboard_id) if leaderboard_id.blank?

      DistributedMutex.synchronize(
        "gamification_generate_leaderboard_positions_#{leaderboard_id}",
        validity: 5.minutes,
      ) do
        leaderboard = DiscourseGamification::GamificationLeaderboard.find_by(id: leaderboard_id)
        return unless leaderboard

        DiscourseGamification::GamificationLeaderboardScore.calculate_scores(
          leaderboard,
          since_date: leaderboard.from_date || Date.new(2000, 1, 1),
        )
        DiscourseGamification::LeaderboardCachedView.new(leaderboard).create
      end
    end
  end
end
