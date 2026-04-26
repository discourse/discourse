# frozen_string_literal: true

describe User, type: :model do
  fab!(:user)
  fab!(:leaderboard, :gamification_leaderboard)

  before do
    Fabricate(
      :gamification_leaderboard_score,
      leaderboard_id: leaderboard.id,
      user_id: user.id,
      score: 10,
      date: 8.days.ago,
    )
    Fabricate(
      :gamification_leaderboard_score,
      leaderboard_id: leaderboard.id,
      user_id: user.id,
      score: 25,
      date: 5.days.ago,
    )
    leaderboard.update(from_date: 5.days.ago.to_date)

    DiscourseGamification::LeaderboardCachedView.create_all
  end

  describe "#gamification_score" do
    it "returns default leaderboard 'all_time' total score" do
      total =
        DiscourseGamification::GamificationLeaderboardScore.where(
          user_id: user.id,
          leaderboard_id: leaderboard.id,
        ).sum(:score)
      expect(total).to eq(35)
      expect(user.gamification_score).to eq(25)
    end
  end
end
