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

  fab!(:u0) { Fabricate(:user) }
  fab!(:u1) { Fabricate(:user) }

  def create_reviewables(count)
    (1..count).each do |i|
      r = Fabricate(:reviewable_flagged_post)
      r.add_score(u0, PostActionType.types[:off_topic])
      r.add_score(u1, PostActionType.types[:off_topic])
      r.update!(score: i)
    end
  end

  it "needs a minimum amount of reviewables before it calculates anything" do
    create_reviewables(5)
    Jobs::ReviewablePriorities.new.execute({})
    expect(Reviewable.min_score_for_priority(:low)).to eq(0.0)
    expect(Reviewable.min_score_for_priority(:medium)).to eq(0.0)
    expect(Reviewable.min_score_for_priority(:high)).to eq(0.0)
    expect(Reviewable.score_required_to_hide_post).to eq(8.33)
  end

  it "will set priorities based on the maximum score" do
    create_reviewables(Jobs::ReviewablePriorities.min_reviewables)
    Jobs::ReviewablePriorities.new.execute({})

    expect(Reviewable.min_score_for_priority(:low)).to eq(0.0)
    expect(Reviewable.min_score_for_priority(:medium)).to eq(8.0)
    expect(Reviewable.min_score_for_priority('medium')).to eq(8.0)
    expect(Reviewable.min_score_for_priority(:high)).to eq(13.0)
    expect(Reviewable.score_required_to_hide_post).to eq(8.66)
  end

end
