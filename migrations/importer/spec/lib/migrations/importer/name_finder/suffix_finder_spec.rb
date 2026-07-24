# frozen_string_literal: true

RSpec.describe Migrations::Importer::SuffixFinder do
  subject(:finder) { described_class.new }

  describe "#find_max_suffixes" do
    it "returns the end of the first range for each base" do
      names = %w[john_1 john_2 john_3 john_4 john_1983 john_2001 john_9999]
      result = finder.find_max_suffixes(names)

      expect(result).to eq({ "john" => 4 })
    end

    it "handles multiple bases independently" do
      names = %w[alice_1 alice_2 alice_3 bob_5 bob_6 bob_7 bob_8]
      result = finder.find_max_suffixes(names)

      expect(result).to eq({ "alice" => 3, "bob" => 8 })
    end

    it "groups suffixes with gaps < 100 into the same range" do
      names = %w[user_10 user_20 user_30 user_99 user_200]
      result = finder.find_max_suffixes(names)

      expect(result).to eq({ "user" => 99 })
    end

    it "splits ranges when gap >= 100" do
      names = %w[user_1 user_2 user_150 user_151]
      result = finder.find_max_suffixes(names)

      expect(result).to eq({ "user" => 2 })
    end

    it "keeps the first range regardless of size" do
      names = %w[user_1 user_2 user_500 user_501]
      result = finder.find_max_suffixes(names)

      expect(result).to eq({ "user" => 2 })
    end

    it "ignores ranges < 300 elements except the first range" do
      names =
        (1..5).map { |i| "user_#{i}" } + (1000..1100).map { |i| "user_#{i}" } +
          (2000..2500).map { |i| "user_#{i}" }
      result = finder.find_max_suffixes(names)

      # First range: [1..5] (5 elements)
      # Second range: [1000..1100] (101 elements, < 300, ignored)
      # Third range: [2000..2500] (501 elements, >= 300, kept but not first)
      expect(result).to eq({ "user" => 2500 })
    end

    it "handles single suffix as a valid first range" do
      names = ["admin_42"]
      result = finder.find_max_suffixes(names)

      expect(result).to eq({ "admin" => 42 })
    end

    it "handles empty input" do
      result = finder.find_max_suffixes([])

      expect(result).to eq({})
    end

    it "handles names without suffixes" do
      names = %w[john alice bob]
      result = finder.find_max_suffixes(names)

      expect(result).to eq({})
    end

    it "handles mixed names with and without suffixes" do
      names = %w[john john_1 john_2 alice alice_5]
      result = finder.find_max_suffixes(names)

      expect(result).to eq({ "john" => 2, "alice" => 5 })
    end

    it "handles unsorted input" do
      names = %w[user_5 user_1 user_3 user_2 user_4]
      result = finder.find_max_suffixes(names)

      expect(result).to eq({ "user" => 5 })
    end

    it "handles large gaps creating single-element ranges" do
      names = %w[user_1 user_500 user_1000 user_1500]
      result = finder.find_max_suffixes(names)

      expect(result).to eq({ "user" => 1 })
    end

    it "handles consecutive large ranges" do
      names = (1..400).map { |i| "user_#{i}" } + (600..1000).map { |i| "user_#{i}" }
      result = finder.find_max_suffixes(names)

      # First range: [1..400] (400 elements)
      # Gap of 199 between 400 and 600 (>= 100, splits)
      # Second range: [600..1000] (401 elements, >= 300)
      expect(result).to eq({ "user" => 1000 })
    end

    context "with gap exactly 99" do
      it "keeps numbers in the same range" do
        names = %w[user_1 user_100 user_200]
        result = finder.find_max_suffixes(names)

        expect(result).to eq({ "user" => 100 })
      end
    end

    context "with gap exactly 100" do
      it "splits into separate ranges" do
        names = %w[user_1 user_101 user_201]
        result = finder.find_max_suffixes(names)

        expect(result).to eq({ "user" => 1 })
      end
    end

    context "with multiple collections" do
      it "combines suffixes from multiple collections" do
        collection1 = %w[user_1 user_2]
        collection2 = %w[user_3 user_4]
        result = finder.find_max_suffixes(collection1, collection2)

        expect(result).to eq({ "user" => 4 })
      end

      it "handles different bases across collections" do
        collection1 = %w[alice_1 alice_2]
        collection2 = %w[bob_5 bob_6]
        result = finder.find_max_suffixes(collection1, collection2)

        expect(result).to eq({ "alice" => 2, "bob" => 6 })
      end

      it "detects gaps across collection boundaries" do
        collection1 = %w[user_1 user_2]
        collection2 = %w[user_150 user_151]
        result = finder.find_max_suffixes(collection1, collection2)

        expect(result).to eq({ "user" => 2 })
      end

      it "handles empty collections" do
        result = finder.find_max_suffixes([], %w[user_1 user_2], [])

        expect(result).to eq({ "user" => 2 })
      end

      it "works with three or more collections" do
        result = finder.find_max_suffixes(%w[user_1 user_2], %w[user_3 user_4], %w[user_5 user_6])

        expect(result).to eq({ "user" => 6 })
      end
    end
  end
end
