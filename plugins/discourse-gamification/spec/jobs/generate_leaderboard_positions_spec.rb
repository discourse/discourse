# frozen_string_literal: true

describe Jobs::GenerateLeaderboardPositions do
  fab!(:user)
  fab!(:leaderboard, :gamification_leaderboard)
  fab!(:score) do
    Fabricate(
      :gamification_leaderboard_score,
      leaderboard_id: leaderboard.id,
      user_id: user.id,
      score: 5,
    )
  end
  let(:leaderboard_positions) { DiscourseGamification::LeaderboardCachedView.new(leaderboard) }

  it "generates leaderboard positions from existing scores" do
    expect { leaderboard_positions.scores }.to raise_error(
      DiscourseGamification::LeaderboardCachedView::NotReadyError,
    )

    DiscourseGamification::GamificationLeaderboardScore.expects(:calculate_scores).never
    described_class.new.execute(leaderboard_id: leaderboard.id)

    expect(leaderboard_positions.scores.length).to eq(1)
    expect(leaderboard_positions.scores.first.total_score).to eq(5)
  end
end
