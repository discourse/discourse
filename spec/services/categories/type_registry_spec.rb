# frozen_string_literal: true

RSpec.describe Categories::TypeRegistry do
  describe ".all" do
    it "returns all registered types" do
      types = described_class.all

      expect(types).to be_a(Hash)
      expect(types.keys).to include(:discussion)
    end
  end

  describe ".get" do
    it "returns the type class for a valid type" do
      expect(described_class.get(:discussion)).to eq(Categories::Types::Discussion)
    end

    it "returns nil for an unknown type" do
      expect(described_class.get(:unknown)).to be_nil
    end
  end

  describe ".get!" do
    it "returns the type class for a valid type" do
      expect(described_class.get!(:discussion)).to eq(Categories::Types::Discussion)
    end

    it "raises ArgumentError for an unknown type" do
      expect { described_class.get!(:unknown) }.to raise_error(
        ArgumentError,
        /Unknown category type/,
      )
    end
  end

  describe ".valid?" do
    it "returns true for a valid type" do
      expect(described_class.valid?(:discussion)).to be true
    end

    it "returns false for an unknown type" do
      expect(described_class.valid?(:unknown)).to be false
    end
  end

  describe ".available" do
    it "returns only types where available? is true" do
      available = described_class.available

      expect(available).to be_a(Hash)
      expect(available[:discussion]).to eq(Categories::Types::Discussion)
    end
  end

  describe ".list" do
    it "returns an array of type metadata" do
      list = described_class.list

      expect(list).to be_an(Array)
      expect(list.first).to include(:id, :name, :icon, :available)
    end

    it "includes the discussion type" do
      list = described_class.list

      discussion = list.find { |t| t[:id] == :discussion }
      expect(discussion).to be_present
      expect(discussion[:icon]).to eq("comments")
    end
  end
end
