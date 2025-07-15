# frozen_string_literal: true

require "rails_helper"

describe User, type: :model do
  fab!(:user)
  fab!(:leaderboard) { Fabricate(:gamification_leaderboard) }

  before do
    Fabricate(:gamification_score, user_id: user.id, score: 10, date: 8.days.ago)
    Fabricate(:gamification_score, user_id: user.id, score: 25, date: 5.days.ago)
    leaderboard.update(from_date: 5.days.ago.to_date)

    DiscourseGamification::LeaderboardCachedView.create_all
  end

  describe "#gamification_score" do
    it "returns default leaderboard 'all_time' total score" do
      expect(DiscourseGamification::GamificationScore.where(user_id: user.id).sum(:score)).to eq(35)
      expect(user.gamification_score).to eq(25)
    end
  end
end
