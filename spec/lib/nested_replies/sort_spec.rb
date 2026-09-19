# frozen_string_literal: true

RSpec.describe NestedReplies::Sort do
  describe ".valid?" do
    it "accepts top, hot, new, old" do
      expect(described_class::ALGORITHMS).to all(
        satisfy { |algorithm| described_class.valid?(algorithm) },
      )
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
        Struct.new(:id, :like_count, :post_number, :created_at).new(20, 1, 3, 1.day.ago),
        Struct.new(:id, :like_count, :post_number, :created_at).new(30, 10, 4, 2.days.ago),
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

    it "sorts by cached thread heat before own heat" do
      hot_scores = { 10 => [5.0, 4.0], 20 => [5.0, 6.0], 30 => [7.0, 1.0] }

      sorted = described_class.sort_in_memory(posts, "hot", hot_scores: hot_scores)

      expect(sorted.map(&:id)).to eq([30, 20, 10])
    end

    it "raises on invalid algorithm" do
      expect { described_class.sort_in_memory(posts, "random") }.to raise_error(ArgumentError)
    end
  end

  describe ".sql_order_expression" do
    it "orders hot scores from the dedicated cache" do
      expression = described_class.sql_order_expression("hot", posts_table: "candidate_posts")

      expect(expression).to include(
        "nested_hot_post_scores.thread_hot_score",
        "nested_hot_post_scores.hot_score",
        "candidate_posts.post_number ASC",
      )
    end

    it "raises on invalid algorithm" do
      expect { described_class.sql_order_expression("bogus") }.to raise_error(ArgumentError)
    end
  end
end
