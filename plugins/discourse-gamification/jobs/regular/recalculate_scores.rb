# frozen_string_literal: true

module Jobs
  class RecalculateScores < ::Jobs::Base
    def execute(args)
      user_id = args[:user_id]
      raise Discourse::InvalidParameters.new(:user_id) if user_id.blank?

      DiscourseGamification::GamificationLeaderboardScore.calculate_all(
        since_date: args[:since] || 10.days.ago,
      )

      DiscourseGamification::LeaderboardCachedView.regenerate_all

      ::MessageBus.publish "/recalculate_scores",
                           {
                             success: true,
                             remaining:
                               DiscourseGamification::RecalculateScoresRateLimiter.remaining,
                             user_id: [user_id],
                           }
    end
  end
end
