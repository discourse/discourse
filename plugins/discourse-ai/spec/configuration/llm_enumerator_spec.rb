# frozen_string_literal: true

RSpec.describe DiscourseAi::Configuration::LlmEnumerator do
  fab!(:fake_model)
  fab!(:ai_agent) { Fabricate(:ai_agent, default_llm_id: fake_model.id) }
  fab!(:llm_model)
  fab!(:seeded_model)
  fab!(:automation) do
    Fabricate(:automation, script: "llm_report", name: "some automation", enabled: true)
  end

  before { enable_current_plugin }

  describe "#values_for_serialization" do
    it "returns an array for that can be used for serialization" do
      fake_model.destroy!

      expect(described_class.values_for_serialization).to contain_exactly(
        {
          id: seeded_model.id,
          name: seeded_model.display_name,
          vision_enabled: seeded_model.vision_enabled,
          vision_mode: "disabled",
          agent_image_capable: false,
          supported_native_tools: [],
        },
        {
          id: llm_model.id,
          name: llm_model.display_name,
          vision_enabled: llm_model.vision_enabled,
          vision_mode: "disabled",
          agent_image_capable: false,
          supported_native_tools: [],
        },
      )
    end

    it "advertises supported provider-native tools" do
      gemini = Fabricate(:gemini_model)
      openai_responses = Fabricate(:llm_model, url: "https://api.openai.com/v1/responses")

      serialized = described_class.values_for_serialization.find { |row| row[:id] == gemini.id }
      expect(serialized[:supported_native_tools]).to eq(%w[web_search web_fetch])

      serialized =
        described_class.values_for_serialization.find { |row| row[:id] == openai_responses.id }
      expect(serialized[:supported_native_tools]).to eq(["web_search"])
    end
  end

  describe "#global_usage" do
    it "returns destination metadata for every built-in feature usage" do
      assign_fake_provider_to(:ai_default_llm_model)
      # The image caption setting only accepts vision-capable agents and models.
      fake_model.update!(vision_enabled: true)
      ai_agent.update!(vision_enabled: true)
      SiteSetting.ai_bot_enabled = true
      SiteSetting.ai_bot_enabled_llms = fake_model.id.to_s
      SiteSetting.ai_helper_proofreader_agent = ai_agent.id
      SiteSetting.ai_helper_enabled = true
      SiteSetting.ai_image_caption_agent = ai_agent.id
      SiteSetting.ai_post_image_captions_enabled = true
      SiteSetting.ai_summarization_agent = ai_agent.id
      SiteSetting.ai_summarization_enabled = true
      SiteSetting.ai_embeddings_semantic_search_hyde_agent = ai_agent.id
      SiteSetting.ai_embeddings_semantic_search_enabled = true
      AiModerationSetting.create!(setting_type: :spam, llm_model: fake_model)
      SiteSetting.ai_spam_detection_enabled = true

      expect(described_class.global_usage.fetch(fake_model.id)).to contain_exactly(
        { id: ai_agent.id, name: ai_agent.name, type: :ai_agent },
        { id: DiscourseAi::Configuration::Module::BOT_ID, type: :ai_bot },
        {
          id: DiscourseAi::Configuration::Module::AI_HELPER_ID,
          name: "Proofread text",
          type: :ai_helper,
        },
        { id: DiscourseAi::Configuration::Module::IMAGE_CAPTION_ID, type: :ai_image_caption },
        { id: DiscourseAi::Configuration::Module::SUMMARIZATION_ID, type: :ai_summarization },
        {
          id: DiscourseAi::Configuration::Module::EMBEDDINGS_ID,
          type: :ai_embeddings_semantic_search,
        },
        { id: DiscourseAi::Configuration::Module::SPAM_ID, type: :ai_spam },
      )
    end

    it "returns destination records for automation and vision delegation" do
      SiteSetting.discourse_automation_enabled = true
      automation.fields.create!(
        component: "text",
        name: "model",
        metadata: {
          value: llm_model.id,
        },
        target: "script",
      )
      vision_target = Fabricate(:llm_model, vision_enabled: true)
      delegating_model =
        Fabricate(:llm_model, display_name: "Delegating model", vision_llm_model: vision_target)

      usage = described_class.global_usage

      expect(usage.fetch(llm_model.id)).to contain_exactly(
        { id: automation.id, name: automation.name, type: :automation },
      )
      expect(usage.fetch(vision_target.id)).to contain_exactly(
        { id: delegating_model.id, name: delegating_model.display_name, type: :vision_delegate },
      )
    end

    it "does not emit automation destinations when their admin routes are unavailable" do
      SiteSetting.discourse_automation_enabled = false
      automation.fields.create!(
        component: "text",
        name: "model",
        metadata: {
          value: llm_model.id,
        },
        target: "script",
      )

      expect(described_class.global_usage).not_to have_key(llm_model.id)
    end
  end
end
