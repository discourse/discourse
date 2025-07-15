# frozen_string_literal: true

module Jobs
  class UpdateScoresForToday < ::Jobs::Scheduled
    every 1.hour

    def execute(args = nil)
      DiscourseGamification::GamificationScore.calculate_scores

      DiscourseGamification::LeaderboardCachedView.purge_all_stale
      DiscourseGamification::LeaderboardCachedView.refresh_all
      DiscourseGamification::LeaderboardCachedView.create_all
    end
  end
end
