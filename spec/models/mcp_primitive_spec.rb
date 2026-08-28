# frozen_string_literal: true

describe McpPrimitive do
  it "stores one exposure record for each primitive type and identifier" do
    described_class.create!(kind: "tool", identifier: "discourse.search", enabled: true)

    duplicate = described_class.new(kind: "tool", identifier: "discourse.search", enabled: false)

    expect(duplicate).not_to be_valid
  end

  it "returns only enabled primitives that are not emergency blocked" do
    exposed = described_class.create!(kind: "tool", identifier: "discourse.search", enabled: true)
    described_class.create!(
      kind: "tool",
      identifier: "discourse.post.set_deleted",
      enabled: true,
      emergency_blocked: true,
    )

    expect(described_class.exposed).to contain_exactly(exposed)
  end
end
