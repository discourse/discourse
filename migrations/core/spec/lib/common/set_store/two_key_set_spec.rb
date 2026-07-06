# frozen_string_literal: true

describe Migrations::SetStore::TwoKeySet do
  let(:set) { described_class.new }

  describe "#add" do
    it "adds values associated with two keys" do
      set.add("key1", "key2", 1)
      expect(set.include?("key1", "key2", 1)).to be true
    end

    it "returns self" do
      expect(set.add("key1", "key2", 1)).to eq set
    end
  end

  describe "#add?" do
    it "returns true when adding a new value" do
      expect(set.add?("key1", "key2", 1)).to be true
    end

    it "returns false when adding an existing value" do
      set.add("key1", "key2", 1)
      expect(set.add?("key1", "key2", 1)).to be false
    end
  end

  describe "#include?" do
    it "returns true for values in the set" do
      set.add("key1", "key2", 1)
      expect(set.include?("key1", "key2", 1)).to be true
    end

    it "returns false for values not in the set" do
      expect(set.include?("key1", "key2", 1)).to be false
    end

    it "returns false for a value missing from an existing set" do
      set.add("key1", "key2", 1)
      expect(set.include?("key1", "key2", 2)).to be false
    end

    it "returns false for non-existent first key" do
      set.add("key1", "key2", 1)
      expect(set.include?("key3", "key2", 1)).to be false
    end

    it "returns false for non-existent second key" do
      set.add("key1", "key2", 1)
      expect(set.include?("key1", "key3", 1)).to be false
    end

    it "doesn't create entries for missing keys" do
      expect(set.empty?).to be true
      set.include?("missing_key1", "missing_key2", 1)
      expect(set.empty?).to be true

      set.add("existing_key", "subkey", 1)
      expect(set.include?("existing_key", "subkey", 1)).to be true
      set.include?("existing_key", "missing_subkey", 1)

      expect(set.include?("existing_key", "subkey", 1)).to be true
      expect(set.include?("existing_key", "missing_subkey", 1)).to be false
    end
  end

  describe "#bulk_add" do
    it "adds multiple key-value pairs at once" do
      set.bulk_add([["key1", "key2", 1], ["key3", "key4", 2]])
      expect(set.include?("key1", "key2", 1)).to be true
      expect(set.include?("key3", "key4", 2)).to be true
    end

    it "handles nil keys correctly" do
      set.bulk_add([[nil, "key2", 1], [nil, "key3", 2], ["key1", nil, 3]])
      expect(set.include?(nil, "key2", 1)).to be true
      expect(set.include?(nil, "key3", 2)).to be true
      expect(set.include?("key1", nil, 3)).to be true
    end

    it "keeps values in the right subkey when a shared key interleaves nil subkeys" do
      set.bulk_add([["k", "a", 1], ["k", nil, 2], ["k", "b", 3], ["k", "c", 4], ["k", nil, 5]])

      expect(set.include?("k", "a", 1)).to be true
      expect(set.include?("k", nil, 2)).to be true
      expect(set.include?("k", "b", 3)).to be true
      expect(set.include?("k", "c", 4)).to be true
      expect(set.include?("k", nil, 5)).to be true
    end

    it "starts a fresh bucket when a nil first key follows another key" do
      set.bulk_add([["a", "x", 1], [nil, "y", 2]])

      expect(set.include?("a", "x", 1)).to be true
      expect(set.include?(nil, "y", 2)).to be true
    end

    it "returns nil" do
      expect(set.bulk_add([["key1", "key2", 1]])).to be_nil
    end
  end

  describe "#empty?" do
    it "returns true for empty sets" do
      expect(set.empty?).to be true
    end

    it "returns false for non-empty sets" do
      set.add("key1", "key2", 1)
      expect(set.empty?).to be false
    end
  end
end
