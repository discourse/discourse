# frozen_string_literal: true

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

  it "lists all persona backed AI features separated by enabled/not enabled" do
    all_modules = DiscourseAi::Configuration::Module.all.select(&:visible?)
    configured_count = all_modules.count(&:enabled?)
    ai_features_page.visit
    ai_features_page.toggle_enabled

    expect(ai_features_page).to have_listed_modules(configured_count)

    ai_features_page.toggle_not_enabled

    expect(ai_features_page).to have_listed_modules(all_modules.size - configured_count)

    screenshot_marker(label: "ai-admin-features")
  end

  it "lists the agent used for the corresponding AI feature" do
    ai_features_page.visit

    ai_features_page.toggle_enabled

    expect(ai_features_page).to have_feature_agent("topic_summaries", summarization_agent.name)
  end

  it "lists the groups allowed to use the AI feature" do
    ai_features_page.visit

    ai_features_page.toggle_enabled

    expect(ai_features_page).to have_feature_groups("topic_summaries", [group_1.name, group_2.name])
  end

  it "lists Discover and Ask AI as separate search features" do
    ask_ai_agent = Fabricate(:ai_agent)
    query_rewriter = Fabricate(:ai_agent)
    follow_up_agent =
      Fabricate(
        :ai_agent,
        allow_personal_messages: true,
        allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
      )
    enable_legacy_discover
    SiteSetting.ai_discover_agent = summarization_agent.id
    SiteSetting.ai_ask_ai_enabled = true
    SiteSetting.ai_ask_ai_agent = ask_ai_agent.id
    SiteSetting.ai_ask_ai_query_rewriter_agent = query_rewriter.id
    SiteSetting.ai_ask_ai_follow_up_agent = follow_up_agent.id

    ai_features_page.visit
    ai_features_page.toggle_enabled

    expect(ai_features_page).to have_feature("discoveries", "Discover (deprecated)")
    expect(ai_features_page).to have_feature("ask_ai", "Ask AI")
    expect(ai_features_page).to have_feature_agent("discoveries", summarization_agent.name)
    expect(ai_features_page).to have_feature_agent("ask_ai", ask_ai_agent.name)
    expect(ai_features_page).to have_feature_agent("ask_ai", query_rewriter.name)
    expect(ai_features_page).to have_feature_agent("ask_ai", follow_up_agent.name)
  end

  it "hides Discover when it is disabled" do
    SiteSetting.ai_discover_enabled = false
    SiteSetting.ai_ask_ai_enabled = true

    ai_features_page.visit
    ai_features_page.toggle_enabled

    expect(ai_features_page).to have_no_feature("discoveries")
    expect(ai_features_page).to have_feature("ask_ai", "Ask AI")
  end

  it "only allows existing enabled sites to configure Discover" do
    enable_legacy_discover

    page.visit(
      "/admin/plugins/discourse-ai/ai-features/#{DiscourseAi::Configuration::Module::SEARCH_ID}/edit",
    )

    expect(form.field("ai_discover_enabled")).to be_enabled

    SiteSetting.ai_discover_enabled = false

    page.visit(
      "/admin/plugins/discourse-ai/ai-features/#{DiscourseAi::Configuration::Module::SEARCH_ID}/edit",
    )

    expect(form).to have_no_enabled_field_with_name("ai_discover_enabled")
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

  it "lets admins discover mixed sentiment backends without workflows" do
    decision_model = Fabricate(:decision_model)
    SiteSetting.enable_discourse_workflows = false
    SiteSetting.ai_sentiment_enabled = true
    SiteSetting.ai_sentiment_emotion_enabled = true
    SiteSetting.ai_sentiment_sentiment_classification_strategy = "decision_model"
    SiteSetting.ai_sentiment_sentiment_decision_model = decision_model.id
    SiteSetting.ai_sentiment_emotion_classification_strategy = "agent"
    SiteSetting.ai_sentiment_emotion_agent = summarization_agent.id

    ai_features_page.visit
    ai_features_page.toggle_enabled

    expect(ai_features_page).to have_feature_decision_model("sentiment", decision_model)
    expect(ai_features_page).to have_feature_agent("emotion", summarization_agent.name)
    expect(ai_features_page).to have_no_feature_groups("sentiment")
    expect(ai_features_page).to have_no_feature_groups("emotion")
  end

  it "lets admins switch sentiment backends before saving and retain their selections" do
    decision_model = Fabricate(:decision_model)
    SiteSetting.ai_sentiment_sentiment_decision_model = decision_model.id
    SiteSetting.ai_sentiment_emotion_decision_model = decision_model.id
    SiteSetting.ai_sentiment_sentiment_agent = summarization_agent.id

    page.visit(
      "/admin/plugins/discourse-ai/ai-features/#{DiscourseAi::Configuration::Module::SENTIMENT_ID}/edit",
    )

    expect(form.field("ai_sentiment_enabled")).to be_unchecked
    expect(form.field("ai_sentiment_emotion_enabled")).to be_unchecked
    expect(form).to have_no_field_with_name("ai_sentiment_sentiment_classification_strategy")
    form.field("ai_sentiment_enabled").check
    expect(form.field("ai_sentiment_emotion_enabled")).to be_unchecked
    expect(form).to have_no_field_with_name("ai_sentiment_emotion_classification_strategy")
    expect(ai_features_page).to have_dedicated_configuration_link
    expect(form).to have_no_field_with_name("ai_sentiment_sentiment_agent")
    expect(form).to have_no_field_with_name("ai_sentiment_sentiment_decision_model")
    expect(form).to have_no_field_with_name("ai_sentiment_model_configs")
    expect(form.field("ai_sentiment_backfill_maximum_posts_per_hour")).to have_value("2500")
    expect(form.field("ai_sentiment_backfill_post_max_age_days")).to have_value("60")
    form.field("ai_sentiment_backfill_maximum_posts_per_hour").fill_in("120")
    form.field("ai_sentiment_backfill_post_max_age_days").fill_in("0")

    form.field("ai_sentiment_sentiment_classification_strategy").select("agent")
    expect(form.field("ai_sentiment_sentiment_agent")).to have_value(summarization_agent.id.to_s)
    expect(form).to have_no_field_with_name("ai_sentiment_sentiment_decision_model")

    form.field("ai_sentiment_sentiment_classification_strategy").select("decision_model")
    expect(form).to have_no_field_with_name("ai_sentiment_sentiment_agent")
    expect(form.field("ai_sentiment_sentiment_decision_model")).to have_value(
      decision_model.id.to_s,
    )
    form.submit
    expect(PageObjects::Components::Toasts.new).to have_success(I18n.t("js.saved"))

    page.refresh
    expect(form.field("ai_sentiment_enabled")).to be_checked
    expect(form.field("ai_sentiment_emotion_enabled")).to be_unchecked
    expect(form).to have_no_field_with_name("ai_sentiment_emotion_classification_strategy")
    expect(form.field("ai_sentiment_backfill_maximum_posts_per_hour")).to have_value("120")
    expect(form.field("ai_sentiment_backfill_post_max_age_days")).to have_value("0")
    expect(form.field("ai_sentiment_sentiment_classification_strategy")).to have_value(
      "decision_model",
    )
    expect(form.field("ai_sentiment_sentiment_decision_model")).to have_value(
      decision_model.id.to_s,
    )

    form.field("ai_sentiment_sentiment_classification_strategy").select("agent")
    expect(form.field("ai_sentiment_sentiment_agent")).to have_value(summarization_agent.id.to_s)

    form.field("ai_sentiment_enabled").uncheck
    form.field("ai_sentiment_emotion_enabled").check
    form.field("ai_sentiment_emotion_classification_strategy").select("decision_model")
    form.submit
    expect(PageObjects::Components::Toasts.new).to have_success(I18n.t("js.saved"))

    page.refresh
    expect(form.field("ai_sentiment_enabled")).to be_unchecked
    expect(form.field("ai_sentiment_emotion_enabled")).to be_checked
    expect(form).to have_no_field_with_name("ai_sentiment_sentiment_classification_strategy")
    expect(form.field("ai_sentiment_emotion_decision_model")).to have_value(decision_model.id.to_s)
  end

  context "with external AI features" do
    let(:fake_plugin) do
      plugin = Plugin::Instance.new
      plugin.path = "#{Rails.root.join("spec/fixtures/plugins/my_plugin/plugin.rb")}"
      plugin
    end

    before do
      DiscourseAi.register_feature(
        module_name: :test_external,
        feature: :test_feature,
        agent_klass: DiscourseAi::TestHelpers::FakeExternalAgent,
        plugin: fake_plugin,
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
