# frozen_string_literal: true

describe Jobs::RecalculateScores do
  fab!(:current_user, :admin)
  fab!(:leaderboard, :gamification_leaderboard)

  before { RateLimiter.enable }

  it "publishes MessageBus and executes job" do
    since = 10.days.ago
    DiscourseGamification::GamificationLeaderboardScore.expects(:calculate_all).with(
      since_date: since,
    )

    DiscourseGamification::LeaderboardCachedView.expects(:regenerate_all)

    MessageBus
      .expects(:publish)
      .with("/recalculate_scores", { success: true, remaining: 5, user_id: [current_user.id] })
      .once
    Jobs::RecalculateScores.new.execute({ since: since, user_id: current_user.id })
  end
end
