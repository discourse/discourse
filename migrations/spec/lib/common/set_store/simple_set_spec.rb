# frozen_string_literal: true

describe Migrations::SetStore::SimpleSet do
  let(:set) { described_class.new }

  describe "#add" do
    it "adds values to the set" do
      set.add(1)
      expect(set.include?(1)).to be true
    end

    it "returns self" do
      expect(set.add(1)).to eq set
    end
  end

  describe "#add?" do
    it "returns true when adding a new value" do
      expect(set.add?(1)).to be true
    end

    it "returns false when adding an existing value" do
      set.add(1)
      expect(set.add?(1)).to be false
    end
  end

  describe "#include?" do
    it "returns true for values in the set" do
      set.add(1)
      expect(set.include?(1)).to be true
    end

    it "returns false for values not in the set" do
      expect(set.include?(1)).to be false
    end
  end

  describe "#bulk_add" do
    it "adds multiple values at once" do
      set.bulk_add([1, 2, 3])
      expect(set.include?(1)).to be true
      expect(set.include?(2)).to be true
      expect(set.include?(3)).to be true
    end

    it "returns nil" do
      expect(set.bulk_add([1, 2, 3])).to be_nil
    end
  end
end
