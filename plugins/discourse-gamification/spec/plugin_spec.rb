# frozen_string_literal: true

require "rails_helper"

describe ::DiscourseGamification do
  let(:user) { Fabricate(:user) }
  let!(:gamification_score) { Fabricate(:gamification_score, user_id: user.id) }

  it "adds gamification_score to the UserCardSerializer" do
    serializer = UserCardSerializer.new(user)
    expect(serializer).to respond_to(:gamification_score)
    expect(serializer.gamification_score).to eq(gamification_score.score)
  end

  context "with leaderboard positions" do
    before { SiteSetting.discourse_gamification_enabled = true }

    it "enqueues job to regenerate leaderboard positions for score ranking strategy changes" do
      expect do SiteSetting.score_ranking_strategy = "row_number" end.to change {
        Jobs::RegenerateLeaderboardPositions.jobs.size
      }.by(1)
    end
  end
end

describe ::DiscourseGamification do
  let(:guardian) { Guardian.new }
  let!(:default_gamification_leaderboard) { Fabricate(:gamification_leaderboard) }

  it "adds default_gamification_leaderboard_id to the SiteSettingSerializer" do
    site = Site.new(guardian)
    serializer = SiteSerializer.new(site)
    expect(serializer).to respond_to(:default_gamification_leaderboard_id)
    expect(serializer.default_gamification_leaderboard_id).to eq(
      default_gamification_leaderboard.id,
    )
  end
end

context "when merging users" do
  fab!(:user_1) { Fabricate(:user) }
  fab!(:user_2) { Fabricate(:user) }
  fab!(:leaderboard) { Fabricate(:gamification_leaderboard) }

  before do
    SiteSetting.discourse_gamification_enabled = true
    DiscourseGamification::LeaderboardCachedView.create_all
    Fabricate.times(1, :topic, user: user_1)
    Fabricate.times(1, :topic, user: user_2)
    DiscourseGamification::GamificationScore.calculate_scores
    DiscourseGamification::LeaderboardCachedView.refresh_all
  end

  it "sums the scores" do
    expect(user_2.gamification_score).to eq(5)

    UserMerger.new(user_1, user_2, Discourse.system_user).merge!
    DiscourseGamification::LeaderboardCachedView.refresh_all

    expect(user_2.gamification_score).to eq(10)
  end
end
