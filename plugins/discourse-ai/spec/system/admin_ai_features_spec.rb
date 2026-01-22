# frozen_string_literal: true

RSpec.describe "Admin AI features configuration", type: :system do
  fab!(:admin)
  fab!(:llm_model)
  fab!(:summarization_persona, :ai_persona)
  fab!(:group_1, :group)
  fab!(:group_2, :group)
  let(:page_header) { PageObjects::Components::DPageHeader.new }
  let(:form) { PageObjects::Components::FormKit.new("form") }
  let(:ai_features_page) { PageObjects::Pages::AdminAiFeatures.new }

  before do
    enable_current_plugin
    summarization_persona.allowed_group_ids = [group_1.id, group_2.id]
    summarization_persona.save!
    assign_fake_provider_to(:ai_default_llm_model)
    SiteSetting.ai_summarization_enabled = true
    SiteSetting.ai_summarization_persona = summarization_persona.id
    sign_in(admin)
  end

  it "lists all persona backed AI features separated by configured/unconfigured" do
    ai_features_page.visit
    ai_features_page.toggle_configured

    expect(ai_features_page).to have_listed_modules(1)

    ai_features_page.toggle_unconfigured

    # this changes as we add more AI features
    expect(ai_features_page).to have_listed_modules(8)
  end

  it "lists the persona used for the corresponding AI feature" do
    ai_features_page.visit

    ai_features_page.toggle_configured

    expect(ai_features_page).to have_feature_persona("topic_summaries", summarization_persona.name)
  end

  it "lists the groups allowed to use the AI feature" do
    ai_features_page.visit

    ai_features_page.toggle_configured

    expect(ai_features_page).to have_feature_groups("topic_summaries", [group_1.name, group_2.name])
  end

  it "shows edit page with grouped settings" do
    ai_features_page.visit

    ai_features_page.click_edit_module("summarization")

    expect(page).to have_current_path("/admin/plugins/discourse-ai/ai-features/1/edit")

    expect(page).to have_css(".ai-feature-editor")
    expect(page).to have_css(".form-kit__section")
    expect(page).to have_css(".form-kit__field")
  end

  it "displays LLM names in compact_list settings" do
    llm1 = Fabricate(:llm_model, display_name: "Test LLM Alpha")
    llm2 = Fabricate(:llm_model, display_name: "Test LLM Beta")

    SiteSetting.ai_bot_enabled = true
    SiteSetting.ai_bot_enabled_llms = "#{llm1.id}|#{llm2.id}"

    page.visit("/admin/plugins/discourse-ai/ai-features/7/edit")

    expect(page).to have_css(".ai-feature-editor")

    field = form.field("ai_bot_enabled_llms")
    expect(field.component).to have_content("Test LLM Alpha")
    expect(field.component).to have_content("Test LLM Beta")
  end
end
