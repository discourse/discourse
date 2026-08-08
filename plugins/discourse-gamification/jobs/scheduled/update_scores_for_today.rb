# frozen_string_literal: true

module Jobs
  class UpdateScoresForToday < ::Jobs::Scheduled
    every 1.hour

    def execute(args = nil)
      return unless SiteSetting.discourse_gamification_enabled

      DiscourseGamification::GamificationLeaderboardScore.calculate_all

      DiscourseGamification::LeaderboardCachedView.purge_all_stale
      DiscourseGamification::LeaderboardCachedView.refresh_all
      DiscourseGamification::LeaderboardCachedView.create_all
    end
  end
end
