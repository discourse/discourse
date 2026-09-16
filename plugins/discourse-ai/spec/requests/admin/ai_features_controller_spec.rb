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

    it "includes automation-related features" do
      SiteSetting.discourse_automation_enabled = true

      get "/admin/plugins/discourse-ai/ai-features.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["ai_features"].count).to eq(
        DiscourseAi::Configuration::Module.all.count(&:visible?),
      )
    end
  end

  describe "#edit" do
    it "returns a success response" do
      get "/admin/plugins/discourse-ai/ai-features/1/edit.json"
      expect(response.parsed_body["module_name"]).to eq("summarization")
    end
  end
end
