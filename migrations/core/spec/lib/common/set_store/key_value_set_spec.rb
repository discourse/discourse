# frozen_string_literal: true

describe Migrations::SetStore::KeyValueSet do
  let(:set) { described_class.new }

  describe "#add" do
    it "adds values associated with keys" do
      set.add("key1", 1)
      expect(set.include?("key1", 1)).to be true
    end

    it "returns self" do
      expect(set.add("key1", 1)).to eq set
    end
  end

  describe "#add?" do
    it "returns true when adding a new value" do
      expect(set.add?("key1", 1)).to be true
    end

    it "returns false when adding an existing value" do
      set.add("key1", 1)
      expect(set.add?("key1", 1)).to be false
    end
  end

  describe "#include?" do
    it "returns true for values in the set" do
      set.add("key1", 1)
      expect(set.include?("key1", 1)).to be true
    end

    it "returns false for values not in the set" do
      expect(set.include?("key1", 1)).to be false
    end

    it "returns false for non-existent keys" do
      set.add("key1", 1)
      expect(set.include?("key2", 1)).to be false
    end

    it "doesn't create entries for missing keys" do
      expect(set.empty?).to be true
      set.include?("missing_key", 1)
      expect(set.empty?).to be true
    end
  end

  describe "#bulk_add" do
    it "adds multiple key-value pairs at once" do
      set.bulk_add([["key1", 1], ["key2", 2]])
      expect(set.include?("key1", 1)).to be true
      expect(set.include?("key2", 2)).to be true
    end

    it "handles nil keys correctly" do
      set.bulk_add([[nil, 1], [nil, 2], ["key1", 3]])
      expect(set.include?(nil, 1)).to be true
      expect(set.include?(nil, 2)).to be true
      expect(set.include?("key1", 3)).to be true
    end

    it "returns nil" do
      expect(set.bulk_add([["key1", 1]])).to be_nil
    end
  end

  describe "#empty?" do
    it "returns true for empty sets" do
      expect(set.empty?).to be true
    end

    it "returns false for non-empty sets" do
      set.add("key", 1)
      expect(set.empty?).to be false
    end
  end
end
