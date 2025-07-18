# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseGamification::GamificationLeaderboard, type: :model do
  fab!(:leaderboard) { Fabricate(:gamification_leaderboard) }

  describe ".resolve_period" do
    it "returns default period given a blank period" do
      expect(leaderboard.default_period).to eq(0)
      expect(leaderboard.resolve_period("")).to eq("all_time")
      expect(leaderboard.resolve_period(nil)).to eq("all_time")
      leaderboard.default_period = 5
      expect(leaderboard.resolve_period(nil)).to eq("daily")
    end

    it "returns given period as is if valid" do
      described_class.periods.keys.each do |period|
        expect(leaderboard.resolve_period(period)).to eq(period)
      end
    end

    it "returns default period/all_time given an invalid period" do
      expect(leaderboard.default_period).to eq(0)
      expect(leaderboard.resolve_period("year")).to eq("all_time")

      leaderboard.default_period = 2
      expect(leaderboard.default_period).to eq(2)
      expect(leaderboard.resolve_period("quart")).to eq("quarterly")

      leaderboard.default_period = -1
      expect(leaderboard.default_period).to eq(-1)
      expect(leaderboard.resolve_period("invalid")).to eq("all_time")
    end
  end
end
