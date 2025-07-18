# frozen_string_literal: true

require "rails_helper"

describe Jobs::UpdateScoresForTenDays do
  let(:user) { Fabricate(:user) }
  let(:user_2) { Fabricate(:user) }
  let(:post) { Fabricate(:post, user: user) }
  let!(:gamification_score) { Fabricate(:gamification_score, user_id: user.id, date: 8.days.ago) }
  let!(:gamification_score_2) do
    Fabricate(:gamification_score, user_id: user_2.id, date: 12.days.ago)
  end
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
    expect(DiscourseGamification::GamificationScore.find_by(user_id: user.id).score).to eq(0)
    run_job
    expect(DiscourseGamification::GamificationScore.find_by(user_id: user.id).score).to eq(5)
  end

  it "does not update scores outside of the last 10 days" do
    expect(DiscourseGamification::GamificationScore.find_by(user_id: user_2.id).score).to eq(0)
    run_job
    expect(DiscourseGamification::GamificationScore.find_by(user_id: user_2.id).score).to eq(0)
  end
end
