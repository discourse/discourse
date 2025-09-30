# frozen_string_literal: true

describe Jobs::GenerateLeaderboardPositions do
  fab!(:leaderboard, :gamification_leaderboard)
  fab!(:score) { Fabricate(:gamification_score, user_id: leaderboard.created_by_id) }
  let(:leaderboard_positions) { DiscourseGamification::LeaderboardCachedView.new(leaderboard) }

  it "generates leaderboard positions" do
    expect { leaderboard_positions.scores }.to raise_error(
      DiscourseGamification::LeaderboardCachedView::NotReadyError,
    )

    described_class.new.execute(leaderboard_id: leaderboard.id)

    expect(leaderboard_positions.scores.length).to eq(1)
  end
end
