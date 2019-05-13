# frozen_string_literal: true

require 'rails_helper'

describe Jobs::ReviewablePriorities do

  it "will set priorities based on the maximum score" do
    (1..6).each { |i| Fabricate(:reviewable, score: i) }
    Jobs::ReviewablePriorities.new.execute({})

    expect(Reviewable.min_score_for_priority('low')).to eq(0.0)
    expect(Reviewable.min_score_for_priority('medium')).to eq(3.0)
    expect(Reviewable.min_score_for_priority('high')).to eq(5.0)
  end

  it "will return 0 if no reviewables exist" do
    Jobs::ReviewablePriorities.new.execute({})

    expect(Reviewable.min_score_for_priority('low')).to eq(0.0)
    expect(Reviewable.min_score_for_priority('medium')).to eq(0.0)
    expect(Reviewable.min_score_for_priority('high')).to eq(0.0)
  end
end
