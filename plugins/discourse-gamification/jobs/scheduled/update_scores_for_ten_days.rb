# frozen_string_literal: true

module Jobs
  class UpdateScoresForTenDays < ::Jobs::Scheduled
    every 1.day

    def execute(args = nil)
      return unless SiteSetting.discourse_gamification_enabled

      DiscourseGamification::GamificationLeaderboardScore.calculate_all(
        since_date: 10.days.ago.midnight,
      )
    end
  end
end
