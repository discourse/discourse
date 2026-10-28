# frozen_string_literal: true

RSpec.describe DiscourseAi::Admin::AiFeaturesController do
  let(:controller) { described_class.new }

  fab!(:admin)
  fab!(:group)
  fab!(:llm_model)
  fab!(:summarizer_agent, :ai_agent)
  fab!(:alternate_summarizer_agent, :ai_agent)

  before do
    enable_current_plugin
    sign_in(admin)
    assign_fake_provider_to(:ai_default_llm_model)
    SiteSetting.ai_bot_enabled = true
  end

  describe "#index" do
    it "lists all features backed by agents" do
      get "/admin/plugins/discourse-ai/ai-features.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["ai_features"].count).to eq(
        DiscourseAi::Configuration::Module.all.count(&:visible?),
      )
    end

    it "reflects changes to the spam detector agent's default language model" do
      hosted_model = Fabricate(:seeded_model)
      agent_id = DiscourseAi::Agents::Agent.system_agents[DiscourseAi::Agents::SpamDetector]

      put "/admin/plugins/discourse-ai/ai-spam.json",
          params: {
            is_enabled: true,
            llm_model_id: hosted_model.id,
            ai_agent_id: agent_id,
          }

      expect(response.status).to eq(200)
      expect(SiteSetting.ai_spam_detection_enabled).to eq(true)

      put "/admin/plugins/discourse-ai/ai-agents/#{agent_id}.json",
          params: {
            ai_agent: {
              default_llm_id: llm_model.id,
            },
          }

      expect(response.status).to eq(200)
      expect(AiAgent.find(agent_id).default_llm_id).to eq(llm_model.id)

      get "/admin/plugins/discourse-ai/ai-features.json"

      expect(response.status).to eq(200)
      spam_module =
        response.parsed_body["ai_features"].find { |ai_module| ai_module["module_name"] == "spam" }
      spam_feature = spam_module["features"].find { |feature| feature["name"] == "inspect_posts" }

      expect(spam_feature["llm_models"]).to contain_exactly(
        "id" => llm_model.id,
        "name" => llm_model.display_name,
      )
    end

    it "lists mixed sentiment backends independently of workflows without exposing endpoint credentials" do
      decision_model = Fabricate(:decision_model)
      endpoint_config = {
        classification_type: "emotion",
        model_name: "custom/emotion",
        endpoint: "srv://private-classifier.example.com",
        api_key: "private-classifier-key",
      }
      SiteSetting.enable_discourse_workflows = false
      SiteSetting.ai_sentiment_enabled = true
      SiteSetting.ai_sentiment_emotion_enabled = true
      SiteSetting.ai_sentiment_sentiment_classification_strategy = "decision_model"
      SiteSetting.ai_sentiment_sentiment_decision_model = decision_model.id
      SiteSetting.ai_sentiment_model_configs = [endpoint_config].to_json

      get "/admin/plugins/discourse-ai/ai-features.json"

      expect(response.status).to eq(200)
      sentiment_module =
        response.parsed_body["ai_features"].find { |entry| entry["module_name"] == "sentiment" }
      expect(sentiment_module["module_enabled"]).to eq(true)
      expect(sentiment_module["features"]).to contain_exactly(
        {
          "name" => "sentiment",
          "agents" => [],
          "llm_models" => [],
          "enabled" => true,
          "backend" => "decision_model",
          "ready" => true,
          "decision_model" => {
            "id" => decision_model.id,
            "display_name" => decision_model.display_name,
          },
        },
        {
          "name" => "emotion",
          "agents" => [],
          "llm_models" => [],
          "enabled" => true,
          "backend" => "classification_model",
          "ready" => true,
          "classification_model" => {
            "model_name" => endpoint_config[:model_name],
          },
        },
      )
      expect(response.body).not_to include(
        endpoint_config[:endpoint],
        endpoint_config[:api_key],
        decision_model.url,
        decision_model.api_key,
      )
    end

    it "keeps enabled sentiment discoverable when its decision model is unconfigured" do
      SiteSetting.ai_sentiment_enabled = true
      SiteSetting.ai_sentiment_sentiment_classification_strategy = "decision_model"

      get "/admin/plugins/discourse-ai/ai-features.json"

      sentiment_module =
        response.parsed_body["ai_features"].find { |entry| entry["module_name"] == "sentiment" }
      expect(sentiment_module["module_enabled"]).to eq(true)
      expect(sentiment_module["features"].find { |entry| entry["name"] == "sentiment" }).to include(
        "enabled" => true,
        "ready" => false,
        "decision_model" => nil,
      )
    end

    it "lists the module as enabled for either capability without coupling the cards" do
      [[true, false], [false, true]].each do |sentiment, emotion|
        SiteSetting.ai_sentiment_enabled = sentiment
        SiteSetting.ai_sentiment_emotion_enabled = emotion

        get "/admin/plugins/discourse-ai/ai-features.json"

        sentiment_module =
          response.parsed_body["ai_features"].find { |entry| entry["module_name"] == "sentiment" }
        expect(sentiment_module["module_enabled"]).to eq(true)
        expect(
          sentiment_module["features"].to_h { |entry| [entry["name"], entry["enabled"]] },
        ).to eq("sentiment" => sentiment, "emotion" => emotion)
      end
    end

    it "includes automation-related features" do
      SiteSetting.discourse_automation_enabled = true

      get "/admin/plugins/discourse-ai/ai-features.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["ai_features"].count).to eq(
        DiscourseAi::Configuration::Module.all.count(&:visible?),
      )
    end
  end

  describe "sentiment background processing settings" do
    it "exposes both controls in the sentiment settings area" do
      get "/admin/config/site_settings.json", params: { filter_area: "ai-features/sentiment" }

      expect(response.status).to eq(200)
      setting_names = response.parsed_body["site_settings"].map { |setting| setting["setting"] }
      expect(setting_names).to include(
        "ai_sentiment_backfill_maximum_posts_per_hour",
        "ai_sentiment_backfill_post_max_age_days",
      )
    end

    it "rejects a negative post age while allowing zero" do
      original_age = SiteSetting.ai_sentiment_backfill_post_max_age_days

      put "/admin/site_settings/ai_sentiment_backfill_post_max_age_days.json",
          params: {
            ai_sentiment_backfill_post_max_age_days: -1,
          }

      expect(response.status).to eq(422)
      expect(SiteSetting.ai_sentiment_backfill_post_max_age_days).to eq(original_age)

      put "/admin/site_settings/ai_sentiment_backfill_post_max_age_days.json",
          params: {
            ai_sentiment_backfill_post_max_age_days: 0,
          }

      expect(response.status).to eq(204)
      expect(SiteSetting.ai_sentiment_backfill_post_max_age_days).to eq(0)
    end
  end

  describe "#edit" do
    it "returns the sentiment configuration module" do
      get "/admin/plugins/discourse-ai/ai-features/#{DiscourseAi::Configuration::Module::SENTIMENT_ID}/edit.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["module_name"]).to eq("sentiment")
      expect(response.parsed_body["module_enabled"]).to eq(false)
      expect(response.parsed_body["features"].map { |entry| entry["enabled"] }).to eq(
        [false, false],
      )
    end

    it "returns a success response" do
      get "/admin/plugins/discourse-ai/ai-features/1/edit.json"
      expect(response.parsed_body["module_name"]).to eq("summarization")
    end
  end
end
