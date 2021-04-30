# frozen_string_literal: true

require 'rails_helper'

describe Jobs::ReviewablePriorities do

  it "needs returns 0s with no existing reviewables" do
    Jobs::ReviewablePriorities.new.execute({})

    expect_min_score(:low, 0.0)
    expect_min_score(:medium, 0.0)
    expect_min_score(:high, 0.0)
    expect(Reviewable.score_required_to_hide_post).to eq(8.33)
  end

  fab!(:user_0) { Fabricate(:user) }
  fab!(:user_1) { Fabricate(:user) }

  def create_reviewables(count)
    (1..count).each { |i| create_with_score(i) }
  end

  def create_with_score(score)
    Fabricate(:reviewable_flagged_post).tap do |reviewable|
      reviewable.add_score(user_0, PostActionType.types[:off_topic])
      reviewable.add_score(user_1, PostActionType.types[:off_topic])
      reviewable.update!(score: score)
    end
  end

  it "needs a minimum amount of reviewables before it calculates anything" do
    create_reviewables(5)

    Jobs::ReviewablePriorities.new.execute({})

    expect_min_score(:low, 0.0)
    expect_min_score(:medium, 0.0)
    expect_min_score(:high, 0.0)
    expect(Reviewable.score_required_to_hide_post).to eq(8.33)
  end

  it "will set priorities based on the maximum score" do
    create_reviewables(Jobs::ReviewablePriorities.min_reviewables)

    Jobs::ReviewablePriorities.new.execute({})

    expect_min_score(:low, SiteSetting.reviewable_low_priority_threshold)
    expect_min_score(:medium, 8.0)
    expect_min_score('medium', 8.0)
    expect_min_score(:high, 13.0)
    expect(Reviewable.score_required_to_hide_post).to eq(8.66)
  end

  it 'ignore negative scores when calculating priorities' do
    create_reviewables(Jobs::ReviewablePriorities.min_reviewables)
    negative_score = -9
    10.times { create_with_score(negative_score) }

    Jobs::ReviewablePriorities.new.execute({})

    expect_min_score(:low, SiteSetting.reviewable_low_priority_threshold)
    expect_min_score(:medium, 8.0)
    expect_min_score(:high, 13.0)
    expect(Reviewable.score_required_to_hide_post).to eq(8.66)
  end

  def expect_min_score(priority, score)
    expect(Reviewable.min_score_for_priority(priority)).to eq(score)
  end
end
