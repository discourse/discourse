# frozen_string_literal: true

RSpec.describe Migrations::Importer::SuffixFinder do
  subject(:finder) { described_class.new }

  describe "#find_highest_in_range" do
    context "with empty input" do
      it "returns nil for empty array" do
        expect(finder.find_highest_in_range([])).to be_nil
      end
    end

    context "with single values" do
      it "returns the single value" do
        expect(finder.find_highest_in_range([5])).to eq(5)
      end

      it "returns first value when all are isolated" do
        expect(finder.find_highest_in_range([1, 102, 999_999])).to eq(1)
      end
    end

    context "with small contiguous ranges (span ≤ 500)" do
      it "returns max from first small range" do
        expect(finder.find_highest_in_range([1, 2, 3, 4])).to eq(4)
      end

      it "ignores isolated outliers and returns max from first range" do
        expect(finder.find_highest_in_range([1, 2, 999_999])).to eq(2)
      end

      it "returns max from first range when multiple small ranges exist" do
        expect(finder.find_highest_in_range([1, 2, 5000, 10_000])).to eq(2)
      end

      it "treats values within gap threshold as contiguous" do
        expect(finder.find_highest_in_range([1, 50, 101])).to eq(101)
      end

      it "treats values beyond gap threshold as separate ranges" do
        expect(finder.find_highest_in_range([1, 102])).to eq(1)
      end
    end

    context "with large ranges (span > 500)" do
      it "returns max from large range when it exists" do
        suffixes = (1..550).to_a
        expect(finder.find_highest_in_range(suffixes)).to eq(550)
      end

      it "returns max from largest problematic range" do
        small_range = (1..10).to_a
        large_range = (5000..6000).to_a
        expect(finder.find_highest_in_range(small_range + large_range)).to eq(6000)
      end

      it "returns highest when multiple large ranges exist" do
        range1 = (1..600).to_a
        range2 = (10_000..11_000).to_a
        expect(finder.find_highest_in_range(range1 + range2)).to eq(11_000)
      end
    end

    context "with unsorted input" do
      it "handles unsorted values correctly" do
        expect(finder.find_highest_in_range([10, 2, 5, 1, 3])).to eq(10)
      end

      it "handles unsorted values with outliers" do
        expect(finder.find_highest_in_range([999_999, 2, 1, 3])).to eq(3)
      end
    end

    context "with custom examples" do
      it "handles [1, 2, 999_999] -> 2" do
        expect(finder.find_highest_in_range([1, 2, 999_999])).to eq(2)
      end

      it "handles [1, 102, 300, 10_000, 11_000, 12_000] -> 12_000" do
        expect(finder.find_highest_in_range([1, 102, 300, 10_000, 11_000, 12_000])).to eq(12_000)
      end
    end
  end
end
