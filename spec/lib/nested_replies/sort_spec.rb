# frozen_string_literal: true

RSpec.describe NestedReplies::Sort do
  describe ".valid?" do
    it "accepts top, new, old" do
      expect(described_class.valid?("top")).to eq(true)
      expect(described_class.valid?("new")).to eq(true)
      expect(described_class.valid?("old")).to eq(true)
    end

    it "rejects unknown algorithms" do
      expect(described_class.valid?("random")).to eq(false)
      expect(described_class.valid?("")).to eq(false)
    end
  end

  describe ".sort_in_memory" do
    let(:posts) do
      [
        Struct.new(:like_count, :post_number, :created_at).new(5, 2, 3.days.ago),
        Struct.new(:like_count, :post_number, :created_at).new(1, 3, 1.day.ago),
        Struct.new(:like_count, :post_number, :created_at).new(10, 4, 2.days.ago),
      ]
    end

    it "sorts by top (like_count desc, post_number asc tiebreaker)" do
      sorted = described_class.sort_in_memory(posts, "top")
      expect(sorted.map(&:post_number)).to eq([4, 2, 3])
    end

    it "sorts by new (created_at desc)" do
      sorted = described_class.sort_in_memory(posts, "new")
      expect(sorted.map(&:post_number)).to eq([3, 4, 2])
    end

    it "sorts by old (post_number asc)" do
      sorted = described_class.sort_in_memory(posts, "old")
      expect(sorted.map(&:post_number)).to eq([2, 3, 4])
    end

    it "raises on invalid algorithm" do
      expect { described_class.sort_in_memory(posts, "random") }.to raise_error(ArgumentError)
    end
  end

  describe ".sql_order_expression" do
    it "raises on invalid algorithm" do
      expect { described_class.sql_order_expression("bogus") }.to raise_error(ArgumentError)
    end
  end
end
