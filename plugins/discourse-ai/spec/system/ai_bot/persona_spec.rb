# frozen_string_literal: true

RSpec.describe "AI personas", type: :system do
  fab!(:admin)
  fab!(:gpt_4) { Fabricate(:llm_model, name: "gpt-4") }

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
    SiteSetting.ai_bot_add_to_header = true
    toggle_enabled_bots(bots: [gpt_4])
    sign_in(admin)
  end

  it "can select and save persona tool options" do
    visit "/admin/plugins/discourse-ai/ai-personas"
    find(".ai-persona-list-editor__new-button").click

    expect(page).to have_current_path("/admin/plugins/discourse-ai/ai-personas/new")

    form = PageObjects::Components::FormKit.new("form")
    form.field("name").fill_in("Test Persona")
    form.field("description").fill_in("This is a test persona.")
    form.field("system_prompt").fill_in("You are a helpful assistant.")
    form.field("tools").select("Update Artifact")
    form.field("toolOptions.UpdateArtifact.update_algorithm").select("full")
    form.submit

    expect(page).to have_current_path(%r{/admin/plugins/discourse-ai/ai-personas/\d+/edit})

    persona = AiPersona.order("id desc").first

    expect(persona.name).to eq("Test Persona")
    expect(persona.description).to eq("This is a test persona.")
    expect(persona.tools.count).to eq(1)
    expect(persona.tools.first[0]).to eq("UpdateArtifact")
    expect(persona.tools.first[1]["update_algorithm"]).to eq("full")
  end

  it "remembers the last selected persona" do
    visit "/"
    find(".d-header .ai-bot-button").click()
    persona_selector =
      PageObjects::Components::SelectKit.new(".persona-llm-selector__persona-dropdown")

    id = DiscourseAi::Personas::Persona.all(user: admin).first.id

    expect(persona_selector).to have_selected_value(id)

    persona_selector.expand
    persona_selector.select_row_by_value(-2)

    visit "/"
    find(".d-header .ai-bot-button").click()
    persona_selector =
      PageObjects::Components::SelectKit.new(".persona-llm-selector__persona-dropdown")
    persona_selector.expand
    expect(persona_selector).to have_selected_value(-2)
  end
end
