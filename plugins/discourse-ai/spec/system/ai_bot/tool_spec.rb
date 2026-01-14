# frozen_string_literal: true

describe "AI Tool Management", type: :system do
  fab!(:admin)
  let(:page_header) { PageObjects::Components::DPageHeader.new }

  before do
    enable_current_plugin
    SiteSetting.ai_embeddings_enabled = true
    sign_in(admin)
  end

  def ensure_can_run_test
    find(".ai-tool-editor__test-button").click

    modal = PageObjects::Modals::AiToolTest.new
    modal.base_currency = "USD"
    modal.target_currency = "EUR"
    modal.amount = "100"

    stub_request(:get, %r{https://open\.er-api\.com/v6/latest/USD}).to_return(
      status: 200,
      body: '{"rates": {"EUR": 0.85}}',
      headers: {
        "Content-Type" => "application/json",
      },
    )
    modal.run_test

    expect(modal).to have_content("exchange_rate")
    expect(modal).to have_content("0.85")

    modal.close
  end

  it "allows admin to create a new AI tool from preset" do
    visit "/admin/plugins/discourse-ai/ai-tools"
    expect(page).to have_content("Tools")

    find(".ai-tool-list-editor__new-button").click

    tool_presets = PageObjects::Components::DMenu.new(find(".ai-tool-list-editor__new-button"))
    tool_presets.option(".btn[data-option='exchange_rate']").click

    required_toggle_css = "#control-parameters-0-required .form-kit__control-checkbox"
    enum_toggle_css = "#control-parameters-0-isEnum .form-kit__control-checkbox"

    expect(page.find(required_toggle_css).checked?).to eq(true)
    expect(page.find(enum_toggle_css).checked?).to eq(false)

    # not allowed to test yet
    expect(page).not_to have_button(".ai-tool-editor__test-button")

    expect(page).not_to have_button(".ai-tool-editor__delete")
    find(".ai-tool-editor__save").click

    expect(page).to have_content("Tool saved")

    last_tool = AiTool.order("id desc").limit(1).first
    visit "/admin/plugins/discourse-ai/ai-tools/#{last_tool.id}/edit"

    ensure_can_run_test

    expect(page.first(required_toggle_css).checked?).to eq(true)
    expect(page.first(enum_toggle_css).checked?).to eq(false)

    visit "/admin/plugins/discourse-ai/ai-personas/new"

    tool_id = AiTool.order("id desc").limit(1).pluck(:id).first
    tool_selector = PageObjects::Components::SelectKit.new("#control-tools .select-kit")
    tool_selector.expand

    tool_selector.select_row_by_value("custom-#{tool_id}")
    expect(tool_selector).to have_selected_value("custom-#{tool_id}")
  end
end
