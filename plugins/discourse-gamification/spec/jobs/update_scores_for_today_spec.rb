# frozen_string_literal: true

describe Jobs::UpdateScoresForToday do
  fab!(:user)
  fab!(:user_2, :user)
  fab!(:post) { Fabricate(:post, user: user, post_number: 2) }
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
    run_job
    score =
      DiscourseGamification::GamificationLeaderboardScore.find_by(
        user_id: user.id,
        leaderboard_id: leaderboard_1.id,
        date: Date.today,
      )
    expect(score&.score).to eq(12)
  end

  it "does not update scores outside of today" do
    run_job
    score =
      DiscourseGamification::GamificationLeaderboardScore.find_by(
        user_id: user_2.id,
        leaderboard_id: leaderboard_1.id,
        date: Date.today,
      )
    expect(score).to be_nil
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

      expect(leaderboard_1_positions.scores.length).to eq(1)
      expect(leaderboard_1_positions.scores.first.attributes).to include(
        "id" => user.id,
        "total_score" => 12,
        "position" => 1,
      )
    end

    it "refreshes leaderboard positions" do
      DiscourseGamification::GamificationLeaderboardScore.calculate_all
      DiscourseGamification::LeaderboardCachedView.create_all

      expect(leaderboard_1_positions.scores.first.attributes).to include(
        "id" => user.id,
        "total_score" => 12,
        "position" => 1,
      )

      run_job

      expect(leaderboard_1_positions.scores.first.attributes).to include(
        "id" => user.id,
        "total_score" => 12,
        "position" => 1,
      )
    end

    it "purges stale leaderboard positions" do
      DiscourseGamification::LeaderboardCachedView.create_all

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

      expect(leaderboard_1_positions.scores.length).to eq(1)
      expect(leaderboard_1_positions.scores.first.attributes).to include(
        "id" => user.id,
        "total_score" => 12,
        "position" => 1,
      )
    end
  end
end
