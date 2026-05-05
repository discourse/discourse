# frozen_string_literal: true

unless defined?(FakeExternalAgent)
  class FakeExternalAgent < DiscourseAi::Agents::Agent
    def tools
      []
    end

    def system_prompt
      "Test agent"
    end
  end
end

RSpec.describe "Admin AI features configuration" do
  fab!(:admin)
  fab!(:llm_model)
  fab!(:summarization_agent, :ai_agent)
  fab!(:group_1, :group)
  fab!(:group_2, :group)
  let(:page_header) { PageObjects::Components::DPageHeader.new }
  let(:form) { PageObjects::Components::FormKit.new("form") }
  let(:ai_features_page) { PageObjects::Pages::AdminAiFeatures.new }

  before do
    enable_current_plugin
    summarization_agent.allowed_group_ids = [group_1.id, group_2.id]
    summarization_agent.save!
    assign_fake_provider_to(:ai_default_llm_model)
    SiteSetting.ai_summarization_enabled = true
    SiteSetting.ai_summarization_agent = summarization_agent.id
    sign_in(admin)
  end

  it "lists all agent backed AI features separated by configured/unconfigured" do
    all_modules = DiscourseAi::Configuration::Module.all
    configured_count = all_modules.count(&:enabled?)

    ai_features_page.visit
    ai_features_page.toggle_configured

    expect(ai_features_page).to have_listed_modules(configured_count)

    ai_features_page.toggle_unconfigured

    expect(ai_features_page).to have_listed_modules(all_modules.size - configured_count)

    screenshot_marker(label: "ai-admin-features")
  end

  it "lists the agent used for the corresponding AI feature" do
    ai_features_page.visit

    ai_features_page.toggle_configured

    expect(ai_features_page).to have_feature_agent("topic_summaries", summarization_agent.name)
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

  it "renders group_list settings as group selectors" do
    SiteSetting.ai_bot_enabled = true
    SiteSetting.ai_bot_allowed_groups = "#{group_1.id}|#{group_2.id}"

    page.visit(
      "/admin/plugins/discourse-ai/ai-features/#{DiscourseAi::Configuration::Module::BOT_ID}/edit",
    )

    expect(page).to have_css(".ai-feature-editor")

    field = form.field("ai_bot_allowed_groups")
    expect(field.component).to have_css(".list-setting")
    expect(field.component).to have_content(group_1.name)
    expect(field.component).to have_content(group_2.name)
  end

  it "displays LLM names in compact_list settings" do
    llm1 = Fabricate(:llm_model, display_name: "Test LLM Alpha")
    llm2 = Fabricate(:llm_model, display_name: "Test LLM Beta")

    SiteSetting.ai_bot_enabled = true
    SiteSetting.ai_bot_enabled_llms = "#{llm1.id}|#{llm2.id}"

    page.visit(
      "/admin/plugins/discourse-ai/ai-features/#{DiscourseAi::Configuration::Module::BOT_ID}/edit",
    )

    expect(page).to have_css(".ai-feature-editor")

    field = form.field("ai_bot_enabled_llms")
    expect(field.component).to have_content("Test LLM Alpha")
    expect(field.component).to have_content("Test LLM Beta")
  end

  context "with external AI features" do
    let(:fake_plugin) do
      plugin = Plugin::Instance.new
      plugin.path = "#{Rails.root}/spec/fixtures/plugins/my_plugin/plugin.rb"
      plugin
    end

    before do
      DiscoursePluginRegistry.register_external_ai_feature(
        {
          module_name: :test_external,
          feature: :test_feature,
          agent_klass: FakeExternalAgent,
          enabled_by_setting: nil,
        },
        fake_plugin,
      )
    end

    after do
      DiscoursePluginRegistry._raw_external_ai_features.reject! do |entry|
        entry[:value][:module_name] == :test_external
      end
    end

    it "shows external modules from the registry" do
      ai_features_page.visit
      expect(page).to have_content("test_external")
      expect(page).to have_content("test_feature")
    end
  end
end
