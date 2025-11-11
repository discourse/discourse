# frozen_string_literal: true

RSpec.describe Migrations::SetStore do
  describe ".create" do
    it "returns a SimpleSet for depth 0" do
      expect(described_class.create(0)).to be_a(::Migrations::SetStore::SimpleSet)
    end

    it "returns a KeyValueSet for depth 1" do
      expect(described_class.create(1)).to be_a(::Migrations::SetStore::KeyValueSet)
    end

    it "returns a TwoKeySet for depth 2" do
      expect(described_class.create(2)).to be_a(::Migrations::SetStore::TwoKeySet)
    end

    it "returns a ThreeKeySet for depth 3" do
      expect(described_class.create(3)).to be_a(::Migrations::SetStore::ThreeKeySet)
    end

    it "raises an error for unsupported depths" do
      expect { described_class.create(4) }.to raise_error(
        ArgumentError,
        "Unsupported nesting depth: 4",
      )
    end
  end
end
