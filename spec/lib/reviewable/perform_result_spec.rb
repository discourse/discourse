# frozen_string_literal: true

RSpec.describe Reviewable::PerformResult do
  fab!(:reviewable, :reviewable_queued_post)

  describe "#initialize" do
    it "sets remove_reviewable_ids to array with reviewable id on success" do
      result = described_class.new(reviewable, :success)

      expect(result.remove_reviewable_ids).to eq([reviewable.id])
    end

    it "sets remove_reviewable_ids to empty array on failure" do
      result = described_class.new(reviewable, :failure)

      expect(result.remove_reviewable_ids).to eq([])
    end
  end
end
