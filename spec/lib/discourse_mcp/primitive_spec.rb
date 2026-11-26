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
  end
end
