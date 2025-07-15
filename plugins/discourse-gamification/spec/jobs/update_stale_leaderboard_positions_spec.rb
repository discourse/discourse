# frozen_string_literal: true

require "rails_helper"

describe Jobs::UpdateStaleLeaderboardPositions do
  fab!(:leaderboard) { Fabricate(:gamification_leaderboard) }
  fab!(:score) { Fabricate(:gamification_score, user_id: leaderboard.created_by_id) }
  let(:leaderboard_positions) { DiscourseGamification::LeaderboardCachedView.new(leaderboard) }

  it "it updates all stale leaderboard positions" do
    DiscourseGamification::LeaderboardCachedView.new(leaderboard).create

    expect(leaderboard_positions.scores.length).to eq(1)
    expect(leaderboard_positions.scores.first.attributes).to include(
      "id" => leaderboard.created_by_id,
      "total_score" => 0,
      "position" => 1,
    )

    allow_any_instance_of(DiscourseGamification::LeaderboardCachedView).to receive(
      :total_scores_query,
    ).and_wrap_original do |original_method, period|
      "#{original_method.call(period)} \n-- This is a new comment"
    end

    expect(leaderboard_positions.stale?).to eq(true)

    described_class.new.execute

    expect(leaderboard_positions.stale?).to eq(false)
    expect(leaderboard_positions.scores.length).to eq(1)
    expect(leaderboard_positions.scores.first.attributes).to include(
      "id" => leaderboard.created_by_id,
      "total_score" => 0,
    )
  end
end
