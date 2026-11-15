# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::McpAppSetup do
  fab!(:admin)

  before { enable_current_plugin }

  describe ".app_steps" do
    it "has steps for every app, with the site's MCP URL filled in" do
      described_class::APPS.each do |app|
        expect(described_class.app_steps(app, site_name: "Acme Forum")).to include(
          DiscourseMcp.resource_url,
        )
        expect(described_class.app_name(app)).to be_present
      end
    end
  end

  describe ".connections" do
    it "says whether each connected app has the scopes a task needs" do
      client =
        McpOauthClient.create!(
          client_id: "claude-client",
          name: "Claude",
          registration_type: "pre_registered",
          trust_state: "approved",
          redirect_uris: ["http://127.0.0.1/callback"],
        )
      authorization =
        McpOauthAuthorization.create!(
          user: admin,
          client:,
          resource: DiscourseMcp.resource_url,
          consented_at: Time.zone.now,
          status: "active",
        )
      authorization.scope_records.create!(name: DiscourseMcp::Scopes::THEMES_READ)

      expect(
        described_class.connections(admin, scopes: [DiscourseMcp::Scopes::THEMES_READ]),
      ).to contain_exactly(a_hash_including(app: "Claude", has_scopes: true))
      expect(
        described_class.connections(admin, scopes: [DiscourseMcp::Scopes::THEMES_WRITE]),
      ).to contain_exactly(a_hash_including(app: "Claude", has_scopes: false))
    end
  end
end
