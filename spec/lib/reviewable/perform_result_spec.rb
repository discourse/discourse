# frozen_string_literal: true

RSpec.describe Reviewable::PerformResult do
  fab!(:reviewable, :reviewable_queued_post)

  describe "#initialize" do
    it "sets update_reviewable_statuses to empty hash" do
      result = described_class.new(reviewable, :success)

      expect(result.update_reviewable_statuses).to eq({})
    end
  end
end
