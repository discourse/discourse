# frozen_string_literal: true

RSpec.describe Categories::TypeRegistry do
  describe ".all" do
    it "includes the discussion type" do
      expect(described_class.all).to include(discussion: Categories::Types::Discussion)
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

  describe ".list" do
    it "returns metadata including the discussion type" do
      discussion = described_class.list.find { |t| t[:id] == :discussion }

      expect(discussion).to include(icon: "comments", available: true)
    end
  end

  describe ".register" do
    let(:test_type) do
      Class.new(Categories::Types::Base).tap { |t| t.type_id(:test_registry_type) }
    end

    after { described_class.all.delete(:test_registry_type) }

    it "registers and exposes a new type" do
      described_class.register(test_type)

      expect(described_class.get(:test_registry_type)).to eq(test_type)
      expect(described_class.valid?(:test_registry_type)).to be true
    end

    it "raises when a type_id is already registered by another owner" do
      described_class.register(test_type, plugin_identifier: "plugin-a")

      other_type = Class.new(Categories::Types::Base).tap { |t| t.type_id(:test_registry_type) }

      expect { described_class.register(other_type, plugin_identifier: "plugin-b") }.to raise_error(
        ArgumentError,
        /already registered/,
      )
    end
  end
end
