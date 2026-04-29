# frozen_string_literal: true

describe Jobs::UpdateScoresForTenDays do
  fab!(:user)
  fab!(:user_2, :user)
  fab!(:leaderboard, :gamification_leaderboard)
  let!(:topic_user_created) { Fabricate(:topic, user: user) }
  let!(:topic_user_2_created) { Fabricate(:topic, user: user_2) }

  def run_job
    described_class.new.execute
  end

  before do
    topic_user_created.update(created_at: 8.days.ago)
    topic_user_2_created.update(created_at: 12.days.ago)
  end

  it "updates all scores within the last 10 days" do
    run_job
    score =
      DiscourseGamification::GamificationLeaderboardScore.where(
        user_id: user.id,
        leaderboard_id: leaderboard.id,
      ).sum(:score)
    expect(score).to eq(5)
  end

  it "does not update scores outside of the last 10 days" do
    run_job
    score =
      DiscourseGamification::GamificationLeaderboardScore.where(
        user_id: user_2.id,
        leaderboard_id: leaderboard.id,
      ).sum(:score)
    expect(score).to eq(0)
  end
end
