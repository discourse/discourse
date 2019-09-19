# frozen_string_literal: true

require 'rails_helper'

describe Jobs::ReviewablePriorities do

  it "needs returns 0s with no existing reviewables" do
    Jobs::ReviewablePriorities.new.execute({})
    expect(Reviewable.min_score_for_priority(:low)).to eq(0.0)
    expect(Reviewable.min_score_for_priority(:medium)).to eq(0.0)
    expect(Reviewable.min_score_for_priority(:high)).to eq(0.0)
    expect(Reviewable.score_required_to_hide_post).to eq(8.33)
  end

  it "needs a minimum amount of reviewables before it calculates anything" do
    (1..5).each { |i| Fabricate(:reviewable, score: i) }
    Jobs::ReviewablePriorities.new.execute({})
    expect(Reviewable.min_score_for_priority(:low)).to eq(0.0)
    expect(Reviewable.min_score_for_priority(:medium)).to eq(0.0)
    expect(Reviewable.min_score_for_priority(:high)).to eq(0.0)
    expect(Reviewable.score_required_to_hide_post).to eq(8.33)
  end

  it "will set priorities based on the maximum score" do
    (1..Jobs::ReviewablePriorities.min_reviewables).each { |i| Fabricate(:reviewable, score: i) }
    Jobs::ReviewablePriorities.new.execute({})

    expect(Reviewable.min_score_for_priority(:low)).to eq(0.0)
    expect(Reviewable.min_score_for_priority(:medium)).to eq(8.0)
    expect(Reviewable.min_score_for_priority('medium')).to eq(8.0)
    expect(Reviewable.min_score_for_priority(:high)).to eq(13.0)
    expect(Reviewable.score_required_to_hide_post).to eq(8.66)
  end

end
