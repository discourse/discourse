# frozen_string_literal: true

describe DiscourseMcp::Access do
  fab!(:group)
  fab!(:other_group, :group)
  fab!(:user)
  fab!(:admin)

  before do
    group.add(user)
    other_group.add(user)
  end

  describe ".eligible_scopes" do
    it "includes the initial scope for an eligible user with an older access rule" do
      McpGroupScope.create!(group: group, scope: "mcp:content:write")

      expect(described_class.eligible_scopes(user)).to contain_exactly(
        "mcp:content:write",
        "mcp:profile:read",
      )
    end

    it "returns the union of scopes from all of the user's groups" do
      McpGroupScope.create!(group: group, scope: "mcp:profile:read")
      McpGroupScope.create!(group: other_group, scope: "mcp:content:write")
      McpGroupScope.create!(group: other_group, scope: "mcp:profile:read")

      expect(described_class.eligible_scopes(user)).to contain_exactly(
        "mcp:profile:read",
        "mcp:content:write",
      )
    end

    it "pre-registers editable scopes for admins" do
      expect(described_class.eligible_scopes(admin)).to eq(DiscourseMcp.registry.scopes)
      expect(
        McpGroupScope.where(group_id: Group::AUTO_GROUPS[:admins]).order(:scope).pluck(:scope),
      ).to eq(DiscourseMcp.registry.scopes)

      McpAccessRuleUpdater.replace!(
        actor: admin,
        group_id: Group::AUTO_GROUPS[:admins],
        scopes: ["mcp:profile:read"],
      )

      expect(described_class.eligible_scopes(admin)).to eq(["mcp:profile:read"])
    end

    it "returns no scopes for an inactive user" do
      user.update!(active: false)
      McpGroupScope.create!(group: group, scope: "mcp:profile:read")

      expect(described_class.eligible_scopes(user)).to be_empty
    end
  end

  describe ".eligible_for_exposed_primitive?" do
    it "requires an enabled server and an exposed primitive covered by the user's scopes" do
      SiteSetting.mcp_server_enabled = true
      McpGroupScope.create!(group: group, scope: "mcp:profile:read")
      primitive =
        McpPrimitive.create!(kind: "tool", identifier: "discourse.current_user.get", enabled: false)

      expect(described_class.eligible_for_exposed_primitive?(user)).to eq(false)

      primitive.update!(enabled: true)
      expect(described_class.eligible_for_exposed_primitive?(user)).to eq(true)

      SiteSetting.mcp_server_enabled = false
      expect(described_class.eligible_for_exposed_primitive?(user)).to eq(false)
    end
  end

  describe "group lifecycle" do
    it "removes access when its group is deleted" do
      McpGroupScope.create!(group: group, scope: "mcp:profile:read")

      group.destroy!

      expect(McpGroupScope.where(group_id: group.id)).to be_empty
    end
  end
end
