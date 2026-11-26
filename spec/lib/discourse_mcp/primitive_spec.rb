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

    it "rejects a default_enabled that isn't a boolean" do
      [nil, "yes"].each do |default_enabled|
        expect { described_class.new(**attributes, default_enabled:) }.to raise_error(
          ArgumentError,
          "invalid MCP primitive default_enabled",
        )
      end
    end
  end

  describe "#default_enabled?" do
    let(:attributes) do
      {
        identifier: "test_tool",
        kind: :tool,
        title: "Test tool",
        description: "A test tool",
        implementation: ->(**) {},
      }
    end

    it "is off whatever the risk, unless the primitive opts in" do
      described_class::RISKS.each do |risk|
        expect(described_class.new(**attributes, risk:)).not_to be_default_enabled
        expect(
          described_class.new(**attributes, risk:, default_enabled: true),
        ).to be_default_enabled
      end
    end
  end
end
