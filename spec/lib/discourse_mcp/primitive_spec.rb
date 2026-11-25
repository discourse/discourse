# frozen_string_literal: true

describe DiscourseMcp::Primitive do
  describe ".new" do
    let(:attributes) do
      {
        identifier: "test_tool",
        kind: :tool,
        title: "Test tool",
        description: "A test tool",
        implementation: ->(**) {},
      }
    end

    it "preserves primitive validation errors" do
      expect { described_class.new(**attributes, kind: :invalid) }.to raise_error(
        ArgumentError,
        "invalid MCP primitive kind",
      )
    end

    it "preserves errors raised while parsing schemas" do
      expect do
        described_class.new(**attributes, input_schema: { type: "object", pattern: "[" })
      end.to raise_error(RegexpError)
    end

    it "rejects a default exposure that isn't a boolean" do
      expect { described_class.new(**attributes, default_exposed: "yes") }.to raise_error(
        ArgumentError,
        "invalid MCP primitive default exposure",
      )
    end
  end

  describe "#default_exposed?" do
    let(:attributes) do
      {
        identifier: "test_tool",
        kind: :tool,
        title: "Test tool",
        description: "A test tool",
        implementation: ->(**) {},
      }
    end

    it "exposes primitives that only act inside the site" do
      %i[read write administration destructive].each do |risk|
        expect(described_class.new(**attributes, risk:)).to be_default_exposed
      end
    end

    it "keeps moderation and outside effects unexposed" do
      %i[moderation external_side_effect].each do |risk|
        expect(described_class.new(**attributes, risk:)).not_to be_default_exposed
      end
    end

    it "lets a primitive choose its own default" do
      expect(
        described_class.new(**attributes, risk: :moderation, default_exposed: true),
      ).to be_default_exposed
      expect(described_class.new(**attributes, default_exposed: false)).not_to be_default_exposed
    end
  end
end
