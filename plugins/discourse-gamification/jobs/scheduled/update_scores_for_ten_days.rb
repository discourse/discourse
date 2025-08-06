# frozen_string_literal: true

module Jobs
  class UpdateScoresForTenDays < ::Jobs::Scheduled
    every 1.day

    def execute(args = nil)
      DiscourseGamification::GamificationScore.calculate_scores(since_date: 10.days.ago.midnight)
    end
  end
end
