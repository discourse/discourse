# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::McpThemeAccess do
  fab!(:admin)
  fab!(:moderator)

  let(:admins_group_id) { Group::AUTO_GROUPS[:admins] }

  before { enable_current_plugin }

  def expose(*primitive_ids)
    primitive_ids.each do |primitive_id|
      kind, identifier = primitive_id.split(":", 2)
      McpPrimitive.create!(kind:, identifier:, enabled: true)
    end
  end

  def create_client(name)
    McpOauthClient.create!(
      client_id: "#{name.parameterize}-client",
      name:,
      registration_type: "pre_registered",
      trust_state: "approved",
      redirect_uris: ["http://127.0.0.1/callback"],
    )
  end

  def authorize(user, client, scopes:)
    McpOauthAuthorization
      .create!(
        user:,
        client:,
        resource: DiscourseMcp.resource_url,
        consented_at: Time.zone.now,
        status: "active",
      )
      .tap { |authorization| scopes.each { |name| authorization.scope_records.create!(name:) } }
  end

  describe ".changes" do
    it "lists everything still needed on a site that hasn't used MCP" do
      McpGroupScope.where(group_id: admins_group_id).delete_all
      McpGroupScope.create!(group_id: admins_group_id, scope: DiscourseMcp::INITIAL_SCOPE)

      expect(described_class.changes.map(&:key)).to eq(%i[server tools admin_scopes])
      expect(described_class.changes.find { |change| change.key == :tools }.after).to eq(
        described_class::THEME_TOOL_IDS,
      )
      expect(described_class).not_to be_ready
    end

    it "is empty once the server is on and apps can use the theme tools" do
      SiteSetting.mcp_server_enabled = true
      expose(*described_class::THEME_TOOL_IDS)

      expect(described_class.changes).to be_empty
      expect(described_class).to be_ready
    end
  end

  describe ".enable!" do
    it "turns on the server and the theme tools, and keeps everything else as it was" do
      expose("tool:discourse_search")
      McpPrimitive.create!(kind: "tool", identifier: "discourse_create_topic", enabled: false)
      McpGroupScope.where(group_id: admins_group_id).delete_all
      McpGroupScope.create!(group_id: admins_group_id, scope: DiscourseMcp::Scopes::THEMES_READ)

      expect(described_class.enable!(guardian: admin.guardian)).to eq(true)

      exposed = McpPrimitive.exposed.pluck(:kind, :identifier).map { |kind, id| "#{kind}:#{id}" }
      expect(exposed).to contain_exactly("tool:discourse_search", *described_class::THEME_TOOL_IDS)
      expect(McpGroupScope.where(group_id: admins_group_id).pluck(:scope)).to include(
        *described_class::THEME_SCOPES,
      )
      expect(SiteSetting.mcp_server_enabled).to eq(true)
      expect(described_class).to be_ready
    end

    it "leaves theme tools blocked in an emergency off" do
      McpPrimitive.create!(
        kind: "tool",
        identifier: "discourse_update_theme",
        enabled: false,
        emergency_blocked: true,
      )

      described_class.enable!(guardian: admin.guardian)

      expect(McpPrimitive.exposed.pluck(:identifier)).not_to include("discourse_update_theme")
      expect(described_class.blocked_theme_tool_ids).to eq(["tool:discourse_update_theme"])
      expect(described_class).not_to be_ready
    end
  end

  describe ".connections" do
    it "lists the apps connected to the user's account, and whether they have theme access" do
      authorize(admin, create_client("Claude"), scopes: described_class::THEME_SCOPES)
      authorize(admin, create_client("Cursor"), scopes: [DiscourseMcp::INITIAL_SCOPE])
      authorize(moderator, create_client("Other"), scopes: described_class::THEME_SCOPES)

      expect(described_class.connections(admin).map { |c| c.slice(:app, :theme_access) }).to(
        contain_exactly(
          { app: "Claude", theme_access: true },
          { app: "Cursor", theme_access: false },
        ),
      )
    end
  end

  describe ".recent_theme_calls" do
    it "lists the user's latest theme tool calls" do
      client = create_client("Claude")
      McpAuditLog.create!(
        user: admin,
        client:,
        occurred_at: 1.minute.ago,
        method: "tools/call",
        tool: "discourse_create_theme",
        outcome: "success",
      )
      McpAuditLog.create!(
        user: admin,
        occurred_at: Time.zone.now,
        method: "tools/call",
        tool: "discourse_search",
        outcome: "success",
      )

      expect(described_class.recent_theme_calls(admin)).to contain_exactly(
        a_hash_including(tool: "discourse_create_theme", app: "Claude", outcome: "success"),
      )
    end
  end

  describe ".denial" do
    it "is only for administrators who can create themes" do
      expect(described_class.denial(user: admin, phase: :generation)).to be_nil
      expect(described_class.denial(user: moderator, phase: :generation)).to eq(
        I18n.t("discourse_ai.mcp_theme_access.not_allowed"),
      )
    end

    it "respects plugin restrictions" do
      plugin = Plugin::Instance.new
      modifier =
        proc do |decision, request|
          decision.deny!("Not here.") if request.feature == described_class::FEATURE
          decision
        end
      plugin.register_modifier(:admin_assistant_feature_access, &modifier)

      expect(described_class.denial(user: admin, phase: :approval)).to eq("Not here.")
      expect(described_class.visible?(admin)).to eq(false)
    ensure
      DiscoursePluginRegistry.unregister_modifier(
        plugin,
        :admin_assistant_feature_access,
        &modifier
      )
    end

    it "refuses on sites that can't create themes" do
      plugin = Plugin::Instance.new
      modifier = proc { false }
      plugin.register_modifier(:user_guardian_can_create_theme, &modifier)

      expect(described_class.denial(user: admin, phase: :generation)).to eq(
        I18n.t("discourse_ai.mcp_theme_access.themes_unavailable"),
      )
    ensure
      DiscoursePluginRegistry.unregister_modifier(
        plugin,
        :user_guardian_can_create_theme,
        &modifier
      )
    end
  end
end
