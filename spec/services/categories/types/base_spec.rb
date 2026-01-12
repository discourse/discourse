# frozen_string_literal: true

RSpec.describe Categories::Types::Base do
  describe ".available?" do
    it "returns true by default" do
      expect(described_class.available?).to be true
    end
  end

  describe ".type_id" do
    it "returns the underscored class name" do
      expect(described_class.type_id).to eq(:base)
    end
  end

  describe ".icon" do
    it "returns comments by default" do
      expect(described_class.icon).to eq("comments")
    end
  end

  describe ".metadata" do
    it "returns a hash with type information" do
      metadata = described_class.metadata

      expect(metadata[:id]).to eq(:base)
      expect(metadata[:icon]).to eq("comments")
      expect(metadata[:available]).to be true
    end
  end
end
