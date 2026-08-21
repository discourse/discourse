# frozen_string_literal: true

RSpec.describe Admin::McpController do
  fab!(:admin)

  before { sign_in(admin) }

  describe "#capabilities" do
    it "returns the registered OAuth scopes as selectable configuration options" do
      get "/admin/mcp/capabilities.json"

      expect(response.status).to eq(200)
      scopes = response.parsed_body["available_scopes"]
      expect(scopes).to eq(scopes.uniq.sort)
      expect(scopes).to include("mcp:profile:discover", "mcp:content:read", "mcp:content:write")
    end
  end

  describe "#emergency_block" do
    it "immediately blocks and unblocks a registered capability" do
      profile = McpServerProfile.ensure_default!
      params = { capability_id: "tool:discourse.search", blocked: true }

      put "/admin/mcp/capabilities/emergency-block.json", params: params

      expect(response.status).to eq(200)
      policy = profile.capability_policies.find_by!(kind: "tool", identifier: "discourse.search")
      expect(policy).to be_emergency_blocked

      put "/admin/mcp/capabilities/emergency-block.json", params: params.merge(blocked: false)

      expect(response.status).to eq(200)
      expect(policy.reload).not_to be_emergency_blocked
    end
  end
end
