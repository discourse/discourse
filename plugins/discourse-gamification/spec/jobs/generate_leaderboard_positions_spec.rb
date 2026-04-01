# frozen_string_literal: true

describe Jobs::GenerateLeaderboardPositions do
  fab!(:user)
  fab!(:leaderboard, :gamification_leaderboard)
  let(:leaderboard_positions) { DiscourseGamification::LeaderboardCachedView.new(leaderboard) }

  before { Fabricate(:topic, user: user) }

  it "calculates scores and generates leaderboard positions" do
    expect { leaderboard_positions.scores }.to raise_error(
      DiscourseGamification::LeaderboardCachedView::NotReadyError,
    )

    described_class.new.execute(leaderboard_id: leaderboard.id)

    expect(leaderboard_positions.scores.length).to eq(1)
    expect(leaderboard_positions.scores.first.total_score).to eq(5)
  end
end
