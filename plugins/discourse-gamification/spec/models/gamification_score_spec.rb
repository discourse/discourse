# frozen_string_literal: true

RSpec.describe DiscourseGamification::GamificationLeaderboardScore, type: :model do
  fab!(:user)
  fab!(:leaderboard, :gamification_leaderboard)

  before { DiscourseGamification::LeaderboardCachedView.create_all }

  describe ".calculate_scores" do
    it "calculates the scores properly" do
      Fabricate.times(10, :topic, user: user)
      described_class.calculate_scores(leaderboard)
      DiscourseGamification::LeaderboardCachedView.refresh_all
      expect(user.gamification_score).to eq(50)

      user.topics.take(5).each(&:destroy)
      described_class.calculate_scores(leaderboard)
      DiscourseGamification::LeaderboardCachedView.refresh_all
      expect(user.gamification_score).to eq(25)

      user.topics.each(&:destroy)
      described_class.calculate_scores(leaderboard)
      DiscourseGamification::LeaderboardCachedView.refresh_all
      expect(user.gamification_score).to eq(0)
    end

    it "uses leaderboard score overrides" do
      Fabricate.times(5, :topic, user: user)
      leaderboard.update!(score_overrides: { "topic_created" => 10 })
      described_class.calculate_scores(leaderboard)
      DiscourseGamification::LeaderboardCachedView.new(leaderboard).delete
      DiscourseGamification::LeaderboardCachedView.new(leaderboard).create
      expect(user.gamification_score).to eq(50)
    end

    it "disables scorables when override is 0" do
      Fabricate.times(5, :topic, user: user)
      leaderboard.update!(score_overrides: { "topic_created" => 0 })
      described_class.calculate_scores(leaderboard)
      DiscourseGamification::LeaderboardCachedView.new(leaderboard).delete
      DiscourseGamification::LeaderboardCachedView.new(leaderboard).create
      expect(user.gamification_score).to eq(0)
    end
  end
end
