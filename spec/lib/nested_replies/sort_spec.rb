# frozen_string_literal: true

RSpec.describe NestedReplies::Sort do
  describe ".valid?" do
    it "accepts top, hot, new, old" do
      expect(described_class.valid?("top")).to eq(true)
      expect(described_class.valid?("hot")).to eq(true)
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
        Struct.new(:id, :like_count, :post_number, :created_at).new(10, 5, 2, 3.days.ago),
        Struct.new(:id, :like_count, :post_number, :created_at).new(11, 1, 3, 1.day.ago),
        Struct.new(:id, :like_count, :post_number, :created_at).new(12, 10, 4, 2.days.ago),
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

    it "sorts by hot branch score, own score, then post number" do
      hot_scores = { 10 => [1.0, 100.0], 11 => [2.0, 1.0], 12 => [2.0, 2.0] }
      sorted = described_class.sort_in_memory(posts, "hot", hot_scores: hot_scores)
      expect(sorted.map(&:post_number)).to eq([4, 3, 2])
    end

    it "raises on invalid algorithm" do
      expect { described_class.sort_in_memory(posts, "random") }.to raise_error(ArgumentError)
    end
  end

  describe ".sql_order_expression" do
    it "orders hot by branch score, own score, then post number" do
      expect(described_class.sql_order_expression("hot")).to eq(
        "COALESCE(nested_view_post_stats.thread_hot_score, 0) DESC, " \
          "COALESCE(nested_view_post_stats.hot_score, 0) DESC, posts.post_number ASC",
      )
    end

    it "raises on invalid algorithm" do
      expect { described_class.sql_order_expression("bogus") }.to raise_error(ArgumentError)
    end
  end
end
