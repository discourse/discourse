# frozen_string_literal: true

RSpec.describe Categories::Types::Discussion do
  describe ".available?" do
    it "returns true" do
      expect(described_class.available?).to be true
    end
  end

  describe ".type_id" do
    it "returns :discussion" do
      expect(described_class.type_id).to eq(:discussion)
    end
  end

  describe ".icon" do
    it "returns comments" do
      expect(described_class.icon).to eq("comments")
    end
  end

  describe ".enable_plugin" do
    it "does nothing" do
      expect { described_class.enable_plugin }.not_to raise_error
    end
  end

  describe ".configure_category" do
    fab!(:category)

    it "does nothing" do
      expect { described_class.configure_category(category) }.not_to raise_error
    end
  end
end
