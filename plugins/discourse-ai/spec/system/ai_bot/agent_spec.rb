# frozen_string_literal: true

RSpec.describe "AI agents" do
  fab!(:admin)
  fab!(:gpt_4) { Fabricate(:llm_model, name: "gpt-4") }

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
    SiteSetting.ai_bot_add_to_header = true
    toggle_enabled_bots(bots: [gpt_4])
    AiAgent.ensure_users!
    sign_in(admin)
  end

  it "can select and save agent tool options" do
    visit "/admin/plugins/discourse-ai/ai-agents"
    find(".ai-agent-list-editor__new-button").click

    expect(page).to have_current_path("/admin/plugins/discourse-ai/ai-agents/new")

    form = PageObjects::Components::FormKit.new("form")
    form.field("name").fill_in("Test Agent")
    form.field("description").fill_in("This is a test agent.")
    form.field("system_prompt").fill_in("You are a helpful assistant.")
    form.field("tools").select("Update Artifact")
    form.field("toolOptions.UpdateArtifact.update_algorithm").select("full")
    form.submit

    expect(page).to have_current_path(%r{/admin/plugins/discourse-ai/ai-agents/\d+/edit})

    agent = AiAgent.order("id desc").first

    expect(agent.name).to eq("Test Agent")
    expect(agent.description).to eq("This is a test agent.")
    expect(agent.tools.count).to eq(1)
    expect(agent.tools.first[0]).to eq("UpdateArtifact")
    expect(agent.tools.first[1]["update_algorithm"]).to eq("full")
  end

  shared_examples "remembering the agent" do
    it "remembers the last selected agent" do
      ai_pm_homepage = PageObjects::Components::AiPmHomepage.new
      visit "/"
      find(".d-header .ai-bot-button").click()

      first_agent =
        DiscourseAi::AiBot::EntryPoint
          .available_agents(admin)
          .find { |available_agent| available_agent[:allow_personal_messages] }

      expect(ai_pm_homepage).to have_selected_agent(first_agent[:name])

      other_agent = AiAgent.find(-2)
      ai_pm_homepage.select_agent(other_agent.name)

      visit "/"
      find(".d-header .ai-bot-button").click()
      expect(ai_pm_homepage).to have_selected_agent(other_agent.name)
    end
  end

  include_examples "remembering the agent"

  context "with the new select controls" do
    with_select_controls(true)

    include_examples "remembering the agent"
  end
end
