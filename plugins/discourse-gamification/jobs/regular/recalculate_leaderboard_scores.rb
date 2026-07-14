# frozen_string_literal: true

module Jobs
  class RecalculateLeaderboardScores < ::Jobs::Base
    def execute(args)
      leaderboard_id = args[:leaderboard_id]
      raise Discourse::InvalidParameters.new(:leaderboard_id) if leaderboard_id.blank?

      leaderboard = DiscourseGamification::GamificationLeaderboard.find_by(id: leaderboard_id)
      return unless leaderboard

      DiscourseGamification::GamificationLeaderboardScore.calculate_scores(
        leaderboard,
        since_date: leaderboard.from_date || Date.new(2000, 1, 1),
      )

      view = DiscourseGamification::LeaderboardCachedView.new(leaderboard)
      view.delete
      view.create
    end
  end
end
