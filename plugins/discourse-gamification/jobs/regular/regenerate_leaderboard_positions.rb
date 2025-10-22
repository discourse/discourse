# frozen_string_literal: true

module Jobs
  class RegenerateLeaderboardPositions < ::Jobs::Base
    def execute(args = nil)
      DiscourseGamification::LeaderboardCachedView.regenerate_all
    end
  end
end
