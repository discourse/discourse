# frozen_string_literal: true

RSpec.describe "Admin AI persona configuration", type: :system do
  fab!(:admin)
  let(:page_header) { PageObjects::Components::DPageHeader.new }
  let(:form) { PageObjects::Components::FormKit.new("form") }

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
    sign_in(admin)
  end

  it "allows creation of a persona" do
    visit "/admin/plugins/discourse-ai/ai-personas"

    expect(page_header).to be_visible

    find(".ai-persona-list-editor__new-button").click()

    form.field("name").fill_in("Test Persona")
    form.field("description").fill_in("I am a test persona")
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

    expect(page).not_to have_current_path("/admin/plugins/discourse-ai/ai-personas/new")

    persona_id = page.current_path.split("/")[-2].to_i

    persona = AiPersona.find(persona_id)
    expect(persona.name).to eq("Test Persona")
    expect(persona.description).to eq("I am a test persona")
    expect(persona.system_prompt).to eq("You are a helpful bot")
    expect(persona.forced_tool_count).to eq(1)

    expected_tools = [["Read", { "read_private" => nil }, true], ["ListCategories", {}, true]]
    expect(persona.tools).to contain_exactly(*expected_tools)

    # lets also test upgrades here... particularly one options was deleted and another added
    # this ensurse that we can still edit the tool correctly and all options are present
    persona.update!(tools: [["Read", { "got_deleted" => true }]])

    visit "/admin/plugins/discourse-ai/ai-personas/#{persona_id}/edit"

    expect(page).to have_selector("input[name='toolOptions.Read.read_private']")
    expect(page).not_to have_selector("input[name='toolOptions.Read.got_deleted']")
  end

  it "will not allow deletion or editing of system personas" do
    visit "/admin/plugins/discourse-ai/ai-personas/#{DiscourseAi::Personas::Persona.system_personas.values.first}/edit"
    expect(page).not_to have_selector(".ai-persona-editor__delete")
    expect(form.field("system_prompt")).to be_disabled
  end

  it "will enable persona right away when you click on enable but does not save side effects" do
    persona = Fabricate(:ai_persona, enabled: false)

    visit "/admin/plugins/discourse-ai/ai-personas/#{persona.id}/edit"

    form.field("name").fill_in("Test Persona 1")
    form.field("enabled").toggle

    expect(persona.reload.enabled).to eq(true)
    expect(persona.name).not_to eq("Test Persona 1")
  end

  it "enabling a persona doesn't reset other fields" do
    persona = Fabricate(:ai_persona, enabled: false)
    updated_name = "Update persona 1"

    visit "/admin/plugins/discourse-ai/ai-personas/#{persona.id}/edit"

    form.field("name").fill_in(updated_name)
    form.field("enabled").toggle

    expect(persona.reload.enabled).to eq(true)
    expect(form.field("name").value).to eq(updated_name)
  end

  it "toggling a persona's priority doesn't reset other fields" do
    persona = Fabricate(:ai_persona, priority: false)
    updated_name = "Update persona 1"

    visit "/admin/plugins/discourse-ai/ai-personas/#{persona.id}/edit"

    form.field("name").fill_in(updated_name)
    form.field("priority").toggle

    expect(persona.reload.priority).to eq(true)
    expect(form.field("name").value).to eq(updated_name)
  end

  it "can navigate the AI plugin with breadcrumbs" do
    visit "/admin/plugins/discourse-ai/ai-personas"
    expect(page).to have_css(".d-breadcrumbs")
    expect(page).to have_css(".d-breadcrumbs__item", count: 4)
    find(".d-breadcrumbs__item", text: I18n.t("admin_js.admin.plugins.title")).click
    expect(page).to have_current_path("/admin/plugins")
  end
end
