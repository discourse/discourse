# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::Tools::EnableMcpThemeAccess do
  fab!(:admin)
  fab!(:other_admin, :admin)
  fab!(:moderator)
  fab!(:ai_agent)

  let(:context) { DiscourseAi::Agents::BotContext.new(user: admin, messages: []) }
  let(:tool) { described_class.new({}, bot_user: Discourse.system_user, llm: nil, context:) }

  before { enable_current_plugin }

  def build_reviewable(tool_name: described_class.name)
    action =
      AiToolAction.create!(
        tool_name:,
        tool_parameters: {
        },
        ai_agent:,
        bot_user_id: Discourse.system_user.id,
      )
    ReviewableAiToolAction
      .needs_review!(
        target: action,
        created_by: Discourse.system_user,
        reviewable_by_moderator: true,
      )
      .tap do |reviewable|
        reviewable.add_score(
          Discourse.system_user,
          ReviewableScore.types[:needs_approval],
          force_review: true,
        )
      end
  end

  it "needs approval and lists each change on the card" do
    expect(described_class.mandatory_approval?).to eq(true)
    expect(tool.validation_error).to be_nil
    # administrators get every scope by default, so there's no access row
    expect(tool.approval_changes).to contain_exactly(
      { label: "MCP server", before: "Off", after: "On" },
      {
        label: "Tools apps can use",
        before: "Off",
        after: "Get theme, Create theme, Update theme",
      },
    )
    expect(tool.approval_details).to include("JavaScript", "#{Discourse.base_url}/mcp")
  end

  it "changes nothing without approval" do
    expect(tool.invoke).to eq(
      status: "error",
      error: I18n.t("discourse_ai.mcp_theme_access.approval_required"),
    )
    expect(SiteSetting.mcp_server_enabled).to eq(false)
    expect(McpPrimitive.exposed).to be_empty
  end

  it "turns theme access on once an administrator approves it" do
    reviewable = build_reviewable

    reviewable.perform(other_admin, :approve)

    expect(SiteSetting.mcp_server_enabled).to eq(true)
    expect(DiscourseAi::Agents::McpThemeAccess).to be_ready
  end

  it "only runs for a review item that approved this tool" do
    context.user = other_admin
    context.reviewable_id = build_reviewable(tool_name: "change_site_setting").id

    expect(tool.invoke[:error]).to eq(I18n.t("discourse_ai.mcp_theme_access.approval_required"))
    expect(SiteSetting.mcp_server_enabled).to eq(false)
  end

  it "only lets administrators approve it" do
    context.user = moderator
    context.reviewable_id = build_reviewable.id

    expect(tool.invoke[:error]).to eq(I18n.t("discourse_ai.mcp_theme_access.not_allowed"))
    expect(SiteSetting.mcp_server_enabled).to eq(false)
  end

  it "refuses when there's nothing to turn on" do
    DiscourseAi::Agents::McpThemeAccess.enable!(guardian: admin.guardian)

    expect(tool.validation_error[:error]).to eq(
      I18n.t("discourse_ai.mcp_theme_access.already_enabled"),
    )
  end

  it "refuses when a global setting keeps the server off" do
    SiteSetting.stubs(:shadowed_settings).returns(Set[:mcp_server_enabled])

    expect(tool.validation_error[:error]).to eq(
      I18n.t("discourse_ai.mcp_theme_access.server_locked"),
    )
  end
end
