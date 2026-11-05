# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::Tools::ThemeAppHandoff do
  fab!(:admin)
  fab!(:moderator)

  let(:context) { DiscourseAi::Agents::BotContext.new(user: admin, messages: []) }

  before { enable_current_plugin }

  def invoke(**parameters)
    described_class.new(parameters, bot_user: Discourse.system_user, llm: nil, context:).invoke
  end

  it "lists what still has to be turned on, without changing anything" do
    result = nil

    expect { result = invoke }.not_to change { McpPrimitive.count }
    expect(result).to include(status: "needs_setup", mcp_url: "#{Discourse.base_url}/mcp")
    expect(result[:setup_needed]).to include(
      I18n.t("discourse_ai.mcp_theme_access.setup.server"),
      I18n.t(
        "discourse_ai.mcp_theme_access.setup.tools",
        tools: "Get theme, Create theme, Update theme",
      ),
    )
    expect(result[:apps]).to include("Claude (web or desktop)", "ChatGPT")
    expect(SiteSetting.mcp_server_enabled).to eq(false)
  end

  it "gives the chosen app's steps with the site's URL, and a first message to send it" do
    SiteSetting.title = "Acme Forum"
    DiscourseAi::Agents::McpThemeAccess.enable!(guardian: admin.guardian)

    result = invoke(app: "claude", request: "Add a mega menu to the header")

    expect(result).to include(status: "ready")
    expect(result.keys).not_to include(:setup_needed, :apps)
    expect(result[:app_steps]).to include("Acme Forum", "#{Discourse.base_url}/mcp")
    expect(result[:starter_message]).to include(
      Discourse.base_url,
      "Add a mega menu to the header",
      Theme.find_default.name,
    )
  end

  it "says when apps can only sign in from approved domains" do
    SiteSetting.mcp_oauth_client_id_metadata_policy = "approved_domains"
    SiteSetting.mcp_oauth_client_id_metadata_domains = "claude.ai"

    expect(invoke[:sign_in_notes].first).to include("claude.ai")
  end

  it "is only for administrators" do
    context.user = moderator

    expect(invoke).to eq(
      status: "error",
      error: I18n.t("discourse_ai.mcp_theme_access.not_allowed"),
    )
    expect(described_class.available_for_context?(context)).to eq(false)
  end
end
