# frozen_string_literal: true

describe McpAccessRuleUpdater do
  fab!(:admin)
  fab!(:group)

  it "always includes the initial scope in group access" do
    logger = instance_spy(StaffActionLogger, log_custom: nil)
    allow(StaffActionLogger).to receive(:new).with(admin).and_return(logger)

    described_class.replace!(actor: admin, group_id: group.id, scopes: ["mcp:content:read"])

    expect(McpGroupScope.where(group:).order(:scope).pluck(:scope)).to eq(
      %w[mcp:content:read mcp:profile:read],
    )
  end

  it "keeps the previous access rule when staff logging fails" do
    McpGroupScope.create!(group:, scope: "mcp:profile:read")
    logger = instance_spy(StaffActionLogger)
    allow(StaffActionLogger).to receive(:new).with(admin).and_return(logger)
    allow(logger).to receive(:log_custom).and_raise(StandardError)

    expect do
      described_class.replace!(
        actor: admin,
        group_id: group.id,
        scopes: %w[mcp:content:read mcp:content:write],
      )
    end.to raise_error(StandardError)

    expect(McpGroupScope.where(group:).pluck(:scope)).to eq(["mcp:profile:read"])
  end

  it "logs the scopes removed with a group access rule" do
    McpGroupScope.create!(group:, scope: "mcp:profile:read")
    logger = instance_spy(StaffActionLogger, log_custom: nil)
    allow(StaffActionLogger).to receive(:new).with(admin).and_return(logger)

    described_class.delete!(actor: admin, group_id: group.id)

    expect(logger).to have_received(:log_custom).with(
      "mcp_access_rule_deleted",
      group_id: group.id,
      scopes: ["mcp:profile:read"],
    )
  end
end
