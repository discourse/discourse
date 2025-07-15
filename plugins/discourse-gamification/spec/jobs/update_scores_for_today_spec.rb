# frozen_string_literal: true

require "rails_helper"

describe Jobs::UpdateScoresForToday do
  fab!(:user)
  fab!(:user_2) { Fabricate(:user) }
  fab!(:post) { Fabricate(:post, user: user, post_number: 2) }
  fab!(:gamification_score) { Fabricate(:gamification_score, user_id: user.id) }
  fab!(:gamification_score_2) do
    Fabricate(:gamification_score, user_id: user_2.id, date: 2.days.ago)
  end
  fab!(:topic_user_created) { Fabricate(:topic, user: user) }
  fab!(:topic_user_2_created) { Fabricate(:topic, user: user_2) }

  fab!(:leaderboard_1) { Fabricate(:gamification_leaderboard, created_by_id: user.id) }
  fab!(:leaderboard_2) { Fabricate(:gamification_leaderboard, created_by_id: user.id) }
  let(:leaderboard_1_positions) { DiscourseGamification::LeaderboardCachedView.new(leaderboard_1) }
  let(:leaderboard_2_positions) { DiscourseGamification::LeaderboardCachedView.new(leaderboard_2) }

  def run_job
    described_class.new.execute
  end

  before { topic_user_2_created.update(created_at: 2.days.ago) }

  it "updates all scores for today" do
    expect(DiscourseGamification::GamificationScore.find_by(user_id: user.id).score).to eq(0)
    run_job
    expect(DiscourseGamification::GamificationScore.find_by(user_id: user.id).score).to eq(12)
  end

  it "does not update scores outside of today" do
    expect(DiscourseGamification::GamificationScore.find_by(user_id: user_2.id).score).to eq(0)
    run_job
    expect(DiscourseGamification::GamificationScore.find_by(user_id: user_2.id).score).to eq(0)
  end

  context "with leaderboard positions" do
    it "generates new leaderboard positions" do
      ActiveRecord::Base.transaction do
        expect { leaderboard_1_positions.scores }.to raise_error(
          DiscourseGamification::LeaderboardCachedView::NotReadyError,
        )
        expect { leaderboard_2_positions.scores }.to raise_error(
          DiscourseGamification::LeaderboardCachedView::NotReadyError,
        )
      end

      run_job

      expect(leaderboard_1_positions.scores.length).to eq(2)
      expect(leaderboard_1_positions.scores.map(&:attributes)).to include(
        {
          "id" => user.id,
          "total_score" => 12,
          "position" => 1,
          "uploaded_avatar_id" => nil,
          "username" => user.username,
          "name" => user.name,
        },
        {
          "id" => user_2.id,
          "total_score" => 0,
          "position" => 2,
          "uploaded_avatar_id" => nil,
          "username" => user_2.username,
          "name" => user_2.name,
        },
      )
    end

    it "refreshes leaderboard positions" do
      # Force assignment of scores accrued
      DiscourseGamification::GamificationScore.calculate_scores
      DiscourseGamification::LeaderboardCachedView.create_all

      expect(leaderboard_1_positions.scores.map(&:attributes)).to include(
        {
          "id" => user.id,
          "total_score" => 12,
          "position" => 1,
          "uploaded_avatar_id" => nil,
          "username" => user.username,
          "name" => user.name,
        },
        {
          "id" => user_2.id,
          "total_score" => 0,
          "position" => 2,
          "uploaded_avatar_id" => nil,
          "username" => user_2.username,
          "name" => user_2.name,
        },
      )

      Fabricate(:gamification_score, user_id: user_2.id, date: 3.days.ago, score: 2)

      run_job

      expect(leaderboard_1_positions.scores.map(&:attributes)).to include(
        {
          "id" => user.id,
          "total_score" => 12,
          "position" => 1,
          "uploaded_avatar_id" => nil,
          "username" => user.username,
          "name" => user.name,
        },
        {
          "id" => user_2.id,
          "total_score" => 2,
          "position" => 2,
          "uploaded_avatar_id" => nil,
          "username" => user_2.username,
          "name" => user_2.name,
        },
      )
    end

    it "purges stale leaderboard positions" do
      DiscourseGamification::LeaderboardCachedView.create_all

      # Update query to make existing materialized views stale
      allow_any_instance_of(DiscourseGamification::LeaderboardCachedView).to receive(
        :total_scores_query,
      ).and_wrap_original do |original_method, period|
        "#{original_method.call(period)} \n-- This is a new comment"
      end

      expect(leaderboard_1_positions.stale?).to eq(true)
      expect(leaderboard_2_positions.stale?).to eq(true)

      run_job

      expect(leaderboard_1_positions.stale?).to eq(false)
      expect(leaderboard_2_positions.stale?).to eq(false)

      expect(leaderboard_1_positions.scores.length).to eq(2)
      expect(leaderboard_1_positions.scores.map(&:attributes)).to include(
        {
          "id" => user.id,
          "total_score" => 12,
          "position" => 1,
          "uploaded_avatar_id" => nil,
          "username" => user.username,
          "name" => user.name,
        },
        {
          "id" => user_2.id,
          "total_score" => 0,
          "position" => 2,
          "uploaded_avatar_id" => nil,
          "username" => user_2.username,
          "name" => user_2.name,
        },
      )
    end
  end
end
