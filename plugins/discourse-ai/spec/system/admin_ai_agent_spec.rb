# frozen_string_literal: true

RSpec.describe "Admin AI agent configuration" do
  fab!(:admin)
  let(:page_header) { PageObjects::Components::DPageHeader.new }
  let(:form) { PageObjects::Components::FormKit.new("form") }
  let(:agent_editor_page) { PageObjects::Pages::AdminAiAgent.new }
  let(:mcp_tool_selector_modal) { PageObjects::Modals::AiAgentMcpToolSelector.new }

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
    sign_in(admin)
  end

  it "allows creation of a agent" do
    visit "/admin/plugins/discourse-ai/ai-agents"

    expect(page_header).to be_visible

    find(".ai-agent-list-editor__new-button").click()

    expect(page_header).to be_hidden

    form.field("name").fill_in("Test Agent")
    form.field("description").fill_in("I am a test agent")
    form.field("system_prompt").fill_in("You are a helpful bot")

    tool_selector = PageObjects::Components::SelectKit.new("#control-tools .select-kit")
    tool_selector.expand
    tool_selector.select_row_by_value("Read")
    tool_selector.select_row_by_value("ListCategories")
    tool_selector.collapse

    tool_selector = PageObjects::Components::SelectKit.new("#control-forcedTools .select-kit")
    tool_selector.expand
    tool_selector.select_row_by_value("ListCategories")
    tool_selector.select_row_by_value("Read")
    tool_selector.collapse

    form.field("forced_tool_count").select(1)

    form.submit

    expect(page).not_to have_current_path("/admin/plugins/discourse-ai/ai-agents/new")

    agent_id = page.current_path.split("/")[-2].to_i

    agent = AiAgent.find(agent_id)
    expect(agent.name).to eq("Test Agent")
    expect(agent.description).to eq("I am a test agent")
    expect(agent.system_prompt).to eq("You are a helpful bot")
    expect(agent.forced_tool_count).to eq(1)

    expected_tools = [["Read", { "read_private" => nil }, true], ["ListCategories", {}, true]]
    expect(agent.tools).to contain_exactly(*expected_tools)

    # lets also test upgrades here... particularly one options was deleted and another added
    # this ensurse that we can still edit the tool correctly and all options are present
    agent.update!(tools: [["Read", { "got_deleted" => true }]])

    visit "/admin/plugins/discourse-ai/ai-agents/#{agent_id}/edit"

    expect(page).to have_selector("input[name='toolOptions.Read.read_private']")
    expect(page).not_to have_selector("input[name='toolOptions.Read.got_deleted']")
  end

  it "will not allow deletion or editing of system agents" do
    visit "/admin/plugins/discourse-ai/ai-agents/#{DiscourseAi::Agents::Agent.system_agents.values.first}/edit"
    expect(page).not_to have_selector(".ai-agent-editor__delete")
    expect(form.field("system_prompt")).to be_disabled
  end

  it "will enable agent right away when you click on enable but does not save side effects" do
    agent = Fabricate(:ai_agent, enabled: false)

    visit "/admin/plugins/discourse-ai/ai-agents/#{agent.id}/edit"

    form.field("name").fill_in("Test Agent 1")
    form.field("enabled").toggle

    expect(agent.reload.enabled).to eq(true)
    expect(agent.name).not_to eq("Test Agent 1")
  end

  it "enabling a agent doesn't reset other fields" do
    agent = Fabricate(:ai_agent, enabled: false)
    updated_name = "Update agent 1"

    visit "/admin/plugins/discourse-ai/ai-agents/#{agent.id}/edit"

    form.field("name").fill_in(updated_name)
    form.field("enabled").toggle

    expect(agent.reload.enabled).to eq(true)
    expect(form.field("name").value).to eq(updated_name)
  end

  it "toggling a agent's priority doesn't reset other fields" do
    agent = Fabricate(:ai_agent, priority: false)
    updated_name = "Update agent 1"

    visit "/admin/plugins/discourse-ai/ai-agents/#{agent.id}/edit"

    form.field("name").fill_in(updated_name)
    form.field("priority").toggle

    expect(agent.reload.priority).to eq(true)
    expect(form.field("name").value).to eq(updated_name)
  end

  it "can navigate the AI plugin with breadcrumbs" do
    visit "/admin/plugins/discourse-ai/ai-agents"
    expect(page).to have_css(".d-breadcrumbs")
    expect(page).to have_css(".d-breadcrumbs__item", count: 4)
    find(".d-breadcrumbs__item", text: I18n.t("admin_js.admin.plugins.title")).click
    expect(page).to have_current_path("/admin/plugins")
  end

  it "redirects legacy ai-personas routes to ai-agents" do
    agent = Fabricate(:ai_agent)

    visit "/admin/plugins/discourse-ai/ai-personas"
    expect(page).to have_current_path("/admin/plugins/discourse-ai/ai-agents")

    visit "/admin/plugins/discourse-ai/ai-personas/new"
    expect(page).to have_current_path("/admin/plugins/discourse-ai/ai-agents/new")

    visit "/admin/plugins/discourse-ai/ai-personas/#{agent.id}/edit"
    expect(page).to have_current_path("/admin/plugins/discourse-ai/ai-agents/#{agent.id}/edit")
  end

  it "allows selecting a subset of MCP tools for an agent" do
    agent = Fabricate(:ai_agent, name: "Test Agent")
    mcp_server = Fabricate(:ai_mcp_server, name: "GitHub", last_health_status: "healthy")

    DiscourseAi::Mcp::ToolRegistry.stubs(:tool_definitions_for).returns([])
    DiscourseAi::Mcp::ToolRegistry
      .stubs(:tool_definitions_for)
      .with(mcp_server)
      .returns(
        [
          {
            "name" => "search_issues",
            "title" => "Search issues",
            "description" => "Search GitHub issues",
            "inputSchema" => {
              "type" => "object",
              "properties" => {
                "query" => {
                  "type" => "string",
                  "description" => "Search query",
                },
              },
              "required" => ["query"],
            },
          },
          {
            "name" => "create_issue",
            "title" => "Create issue",
            "description" => "Create a GitHub issue",
            "inputSchema" => {
              "type" => "object",
              "properties" => {
                "title" => {
                  "type" => "string",
                  "description" => "Issue title",
                },
              },
              "required" => ["title"],
            },
          },
        ],
      )

    agent_editor_page.visit_edit(agent)
    agent_editor_page.select_mcp_server(mcp_server)

    expect(agent_editor_page).to have_mcp_server_summary(
      "GitHub",
      I18n.t("js.discourse_ai.ai_agent.mcp_server_enabled_tool_count", count: 2),
    )

    agent_editor_page.open_mcp_tool_selector("GitHub")

    expect(mcp_tool_selector_modal).to be_open
    expect(mcp_tool_selector_modal).to have_tool_selected("search_issues")
    expect(mcp_tool_selector_modal).to have_tool_selected("create_issue")

    mcp_tool_selector_modal.toggle_tool("create_issue")

    expect(mcp_tool_selector_modal).to have_selection_summary(1, 2)

    mcp_tool_selector_modal.click_primary_button

    expect(mcp_tool_selector_modal).to be_closed
    expect(agent_editor_page).to have_mcp_server_summary(
      "GitHub",
      I18n.t("js.discourse_ai.ai_agent.mcp_server_enabled_tools", count: 1, total: 2),
    )
    expect(agent_editor_page).to have_mcp_server_action(
      "GitHub",
      I18n.t("js.discourse_ai.ai_agent.mcp_server_edit_tools"),
    )

    agent_editor_page.form.submit

    expect(page).to have_content(I18n.t("js.discourse_ai.ai_agent.saved"))
    wait_for do
      agent
        .reload
        .ai_agent_mcp_servers
        .find_by!(ai_mcp_server_id: mcp_server.id)
        .selected_tool_names == ["search_issues"]
    end

    agent_editor_page.visit_edit(agent)

    expect(agent_editor_page).to have_mcp_server_summary(
      "GitHub",
      I18n.t("js.discourse_ai.ai_agent.mcp_server_enabled_tools", count: 1, total: 2),
    )

    agent_editor_page.open_mcp_tool_selector("GitHub")

    expect(mcp_tool_selector_modal).to have_tool_selected("search_issues")
    expect(mcp_tool_selector_modal).to have_tool_unselected("create_issue")
    expect(mcp_tool_selector_modal).to have_selection_summary(1, 2)
  end
end
