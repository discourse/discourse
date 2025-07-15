# frozen_string_literal: true

require "rails_helper"

describe DiscourseGamification::DirectoryIntegration do
  fab!(:user_1) { Fabricate(:admin) }
  fab!(:user_2) { Fabricate(:user) }
  fab!(:leaderboard) { Fabricate(:gamification_leaderboard) }
  fab!(:score_1) { Fabricate(:gamification_score, user_id: user_1.id, score: 10, date: 8.days.ago) }
  fab!(:score_2) { Fabricate(:gamification_score, user_id: user_1.id, score: 40, date: 3.days.ago) }
  fab!(:score_3) { Fabricate(:gamification_score, user_id: user_2.id, score: 25, date: 5.days.ago) }
  fab!(:score_4) { Fabricate(:gamification_score, user_id: user_2.id, score: 5, date: 2.days.ago) }

  before do
    SiteSetting.discourse_gamification_enabled = true
    DirectoryItem.refresh!
  end

  def all_time_score_for(user)
    user.directory_items.find_by(period_type: 1).gamification_score
  end

  context "with a date-restricted default leaderboard" do
    context "with only a 'from_date'" do
      before do
        leaderboard.update(from_date: 5.days.ago.to_date)
        DirectoryItem.refresh!
      end

      it "returns sum of points earned from leaderboard's 'from_date'" do
        expect(all_time_score_for(user_1)).to eq(40)
        expect(all_time_score_for(user_2)).to eq(30)
      end
    end

    context "with only a 'to_date'" do
      before do
        leaderboard.update(to_date: 4.days.ago.to_date)
        DirectoryItem.refresh!
      end

      it "returns sum of points earned upto leaderboard's 'to_date'" do
        expect(all_time_score_for(user_1)).to eq(10)
        expect(all_time_score_for(user_2)).to eq(25)
      end
    end

    context "with both 'from_date' and 'to_date'" do
      before do
        leaderboard.update(from_date: 5.days.ago.to_date, to_date: 3.days.ago.to_date)
        DirectoryItem.refresh!
      end

      it "returns sum of points earned between leaderboard's 'from_date' and 'to_date'" do
        expect(DiscourseGamification::GamificationScore.where(user: user_1).sum(:score)).to eq(50)
        expect(DiscourseGamification::GamificationScore.where(user: user_2).sum(:score)).to eq(30)

        expect(all_time_score_for(user_1)).to eq(40)
        expect(all_time_score_for(user_2)).to eq(25)
      end
    end
  end

  context "without a date-restricted default leaderboard" do
    it "returns sum of all scores for the period" do
      expect(DiscourseGamification::GamificationScore.where(user: user_1).sum(:score)).to eq(50)
      expect(DiscourseGamification::GamificationScore.where(user: user_2).sum(:score)).to eq(30)

      expect(all_time_score_for(user_1)).to eq(50)
      expect(all_time_score_for(user_2)).to eq(30)
    end
  end
end
