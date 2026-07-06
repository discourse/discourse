# frozen_string_literal: true

describe Migrations::SetStore::ThreeKeySet do
  let(:set) { described_class.new }

  describe "#add" do
    it "adds values associated with three keys" do
      set.add("key1", "key2", "key3", 1)
      expect(set.include?("key1", "key2", "key3", 1)).to be true
    end

    it "returns self" do
      expect(set.add("key1", "key2", "key3", 1)).to eq set
    end
  end

  describe "#add?" do
    it "returns true when adding a new value" do
      expect(set.add?("key1", "key2", "key3", 1)).to be true
    end

    it "returns false when adding an existing value" do
      set.add("key1", "key2", "key3", 1)
      expect(set.add?("key1", "key2", "key3", 1)).to be false
    end
  end

  describe "#include?" do
    it "returns true for values in the set" do
      set.add("key1", "key2", "key3", 1)
      expect(set.include?("key1", "key2", "key3", 1)).to be true
    end

    it "returns false for values not in the set" do
      expect(set.include?("key1", "key2", "key3", 1)).to be false
    end

    it "returns false when only the value is missing from an existing set" do
      set.add("key1", "key2", "key3", 1)
      expect(set.include?("key1", "key2", "key3", 2)).to be false
    end

    it "returns false for non-existent first key" do
      set.add("key1", "key2", "key3", 1)
      expect(set.include?("key4", "key2", "key3", 1)).to be false
    end

    it "returns false for non-existent second key" do
      set.add("key1", "key2", "key3", 1)
      expect(set.include?("key1", "key4", "key3", 1)).to be false
    end

    it "returns false for non-existent third key" do
      set.add("key1", "key2", "key3", 1)
      expect(set.include?("key1", "key2", "key4", 1)).to be false
    end

    it "doesn't create entries for missing keys" do
      expect(set.empty?).to be true
      set.include?("missing_key1", "missing_key2", "missing_key3", 1)
      expect(set.empty?).to be true

      set.add("key1", "key2", "key3", 1)

      set.include?("key1", "missing_key", "any_key", 1)
      set.include?("key1", "key2", "missing_key", 1)

      expect(set.include?("key1", "key2", "key3", 1)).to be true
      expect(set.include?("key1", "missing_key", "any_key", 1)).to be false
      expect(set.include?("key1", "key2", "missing_key", 1)).to be false
    end
  end

  describe "#bulk_add" do
    it "adds multiple key-value pairs at once" do
      set.bulk_add([["key1", "key2", "key3", 1], ["key4", "key5", "key6", 2]])
      expect(set.include?("key1", "key2", "key3", 1)).to be true
      expect(set.include?("key4", "key5", "key6", 2)).to be true
    end

    it "handles nil keys correctly" do
      set.bulk_add([[nil, "key2", "key3", 1], ["key1", nil, "key3", 2], ["key1", "key2", nil, 3]])
      expect(set.include?(nil, "key2", "key3", 1)).to be true
      expect(set.include?("key1", nil, "key3", 2)).to be true
      expect(set.include?("key1", "key2", nil, 3)).to be true
    end

    it "keeps values in their own set when keys are grouped" do
      set.bulk_add(
        [
          ["a", "x", "1", 10],
          ["a", "x", "1", 11],
          ["a", "x", "2", 12],
          ["a", "y", "1", 13],
          ["b", "x", "1", 14],
        ],
      )

      expect(set.include?("a", "x", "1", 10)).to be true
      expect(set.include?("a", "x", "1", 11)).to be true
      expect(set.include?("a", "x", "2", 12)).to be true
      expect(set.include?("a", "y", "1", 13)).to be true
      expect(set.include?("b", "x", "1", 14)).to be true

      expect(set.include?("a", "x", "1", 12)).to be false
      expect(set.include?("a", "x", "2", 10)).to be false
      expect(set.include?("a", "y", "1", 10)).to be false
      expect(set.include?("b", "x", "1", 10)).to be false
    end

    it "handles a first key that changes to nil" do
      set.bulk_add([["a", "x", "1", 1], [nil, "y", "2", 2]])
      expect(set.include?(nil, "y", "2", 2)).to be true
      expect(set.include?("a", "y", "2", 2)).to be false
    end

    it "handles a second key that changes to nil within a group" do
      set.bulk_add([["a", "x", "1", 1], ["a", nil, "1", 2]])
      expect(set.include?("a", nil, "1", 2)).to be true
      expect(set.include?("a", "x", "1", 2)).to be false
    end

    it "handles a third key that changes to nil within a group" do
      set.bulk_add([["a", "x", "1", 1], ["a", "x", nil, 2]])
      expect(set.include?("a", "x", nil, 2)).to be true
      expect(set.include?("a", "x", "1", 2)).to be false
    end

    it "handles a third key that follows a nil third key" do
      set.bulk_add([["a", "x", nil, 1], ["a", "x", "2", 2]])
      expect(set.include?("a", "x", "2", 2)).to be true
      expect(set.include?("a", "x", nil, 2)).to be false
    end

    it "tracks a nil second key after a second key change" do
      set.bulk_add([["a", "x", "1", 1], ["a", "y", "1", 2], ["a", nil, "1", 3]])
      expect(set.include?("a", nil, "1", 3)).to be true
      expect(set.include?("a", "y", "1", 3)).to be false
    end

    it "tracks a nil third key after a second key change" do
      set.bulk_add([["a", "x", "1", 1], ["a", "y", "1", 2], ["a", "y", nil, 3]])
      expect(set.include?("a", "y", nil, 3)).to be true
      expect(set.include?("a", "y", "1", 3)).to be false
    end

    it "tracks a nil third key after a third key change" do
      set.bulk_add([["a", "x", "1", 1], ["a", "x", "2", 2], ["a", "x", nil, 3]])
      expect(set.include?("a", "x", nil, 3)).to be true
      expect(set.include?("a", "x", "2", 3)).to be false
    end

    it "returns nil" do
      expect(set.bulk_add([["key1", "key2", "key3", 1]])).to be_nil
    end
  end

  describe "#empty?" do
    it "returns true for empty sets" do
      expect(set.empty?).to be true
    end

    it "returns false for non-empty sets" do
      set.add("key1", "key2", "key3", 1)
      expect(set.empty?).to be false
    end
  end
end
