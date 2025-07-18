# frozen_string_literal: true

require "rails_helper"

describe Jobs::RecalculateScores do
  fab!(:current_user) { Fabricate(:admin) }

  before { RateLimiter.enable }

  it "publishes MessageBus and executes job" do
    since = 10.days.ago
    DiscourseGamification::GamificationScore.expects(:calculate_scores).with(since_date: since)

    MessageBus
      .expects(:publish)
      .with("/recalculate_scores", { success: true, remaining: 5, user_id: [current_user.id] })
      .once
    Jobs::RecalculateScores.new.execute({ since: since, user_id: current_user.id })
  end
end
