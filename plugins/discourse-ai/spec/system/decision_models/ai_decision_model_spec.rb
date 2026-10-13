# frozen_string_literal: true

RSpec.describe "Managing decision models" do
  fab!(:admin)
  fab!(:ai_secret) { Fabricate(:ai_secret, name: "Self-hosted key") }

  let(:form) { PageObjects::Components::FormKit.new("form") }
  let(:url) { "https://d3.example.com/v1/systemone" }

  before do
    enable_current_plugin
    sign_in(admin)
  end

  it "creates a decision model from a preset after testing it" do
    stub_request(:post, url).to_return(
      status: 200,
      body: { model: "vllm-sr/d3", answers: { greeting: { type: "noul", noul: 0.97 } } }.to_json,
    )

    visit "/admin/plugins/discourse-ai/ai-decision-models"
    find(".ai-decision-models-list-editor__empty-new-button").click
    find("[data-preset-id='vllm-sr-d3'] button").click

    form.field("url").fill_in(url)
    secret_selector = PageObjects::Components::SelectKit.new(".ai-secret-selector__dropdown")
    secret_selector.expand
    secret_selector.select_row_by_value(ai_secret.id)

    find(".ai-decision-model-editor__test").click
    expect(page).to have_css(".ai-decision-model-editor__test-success", text: "97%")

    form.submit

    expect(page).to have_current_path("/admin/plugins/discourse-ai/ai-decision-models")
    expect(DecisionModel.last).to have_attributes(
      display_name: "d3",
      name: "vllm-sr/d3",
      provider: DecisionModel::SYSTEM_ONE,
      url: url,
      ai_secret_id: ai_secret.id,
      vision_enabled: true,
    )
    expect(page).to have_css(".ai-decision-models-list__row", text: "vllm-sr/d3")
  end
end
