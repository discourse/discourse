# frozen_string_literal: true

RSpec.describe Jobs::ReviewablePriorities do
  it "needs returns 0s with no existing reviewables" do
    Jobs::ReviewablePriorities.new.execute({})

    expect_min_score(:low, 0.0)
    expect_min_score(:medium, 0.0)
    expect_min_score(:high, 0.0)
    expect(Reviewable.score_required_to_hide_post).to eq(8.33)
  end

  fab!(:user_0) { Fabricate(:user) }
  fab!(:user_1) { Fabricate(:user) }

  def create_reviewables(count, status: :approved)
    minimum_threshold = SiteSetting.reviewable_low_priority_threshold
    (1..count).each { |i| create_with_score(minimum_threshold + i) }
  end

  def create_with_score(score, status: :approved)
    Fabricate(:reviewable_flagged_post, status: Reviewable.statuses[status]).tap do |reviewable|
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

  context "when there are enough reviewables" do
    let(:medium_threshold) { 8.0 }
    let(:high_threshold) { 13.0 }
    let(:score_to_hide_post) { 8.66 }

    it "will set priorities based on the maximum score" do
      create_reviewables(Jobs::ReviewablePriorities.min_reviewables)

      Jobs::ReviewablePriorities.new.execute({})

      expect_min_score(:low, SiteSetting.reviewable_low_priority_threshold)
      expect_min_score(:medium, medium_threshold)
      expect_min_score(:high, high_threshold)
      expect(Reviewable.score_required_to_hide_post).to eq(score_to_hide_post)
    end

    it "ignore negative scores when calculating priorities" do
      create_reviewables(Jobs::ReviewablePriorities.min_reviewables)
      negative_score = -9
      10.times { create_with_score(negative_score) }

      Jobs::ReviewablePriorities.new.execute({})

      expect_min_score(:low, SiteSetting.reviewable_low_priority_threshold)
      expect_min_score(:medium, medium_threshold)
      expect_min_score(:high, high_threshold)
      expect(Reviewable.score_required_to_hide_post).to eq(score_to_hide_post)
    end

    it "ignores non-approved reviewables" do
      create_reviewables(Jobs::ReviewablePriorities.min_reviewables)
      low_score = 2
      10.times { create_with_score(low_score, status: :pending) }

      Jobs::ReviewablePriorities.new.execute({})

      expect_min_score(:low, SiteSetting.reviewable_low_priority_threshold)
      expect_min_score(:medium, medium_threshold)
      expect_min_score(:high, high_threshold)
      expect(Reviewable.score_required_to_hide_post).to eq(score_to_hide_post)
    end
  end

  def expect_min_score(priority, score)
    expect(Reviewable.min_score_for_priority(priority)).to eq(score)
  end
end
