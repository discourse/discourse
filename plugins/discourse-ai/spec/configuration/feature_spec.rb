# frozen_string_literal: true

RSpec.describe DiscourseAi::Configuration::Feature do
  fab!(:llm_model)
  fab!(:ai_agent) { Fabricate(:ai_agent, default_llm_id: llm_model.id) }

  before { assign_fake_provider_to(:ai_default_llm_model) }

  def allow_configuring_setting(&block)
    DiscourseAi::Completions::Llm.with_prepared_responses(["OK"]) { block.call }
  end

  before { enable_current_plugin }

  describe "#llm_model" do
    context "when agent is not found" do
      it "returns nil when agent_id is invalid" do
        ai_feature =
          described_class.new(
            "topic_summaries",
            "ai_summarization_agent",
            DiscourseAi::Configuration::Module::SUMMARIZATION_ID,
            DiscourseAi::Configuration::Module::SUMMARIZATION,
          )

        SiteSetting.ai_summarization_agent = 999_999
        expect(ai_feature.llm_models).to eq([])
      end
    end

    context "with summarization module" do
      let(:ai_feature) do
        described_class.new(
          "topic_summaries",
          "ai_summarization_agent",
          DiscourseAi::Configuration::Module::SUMMARIZATION_ID,
          DiscourseAi::Configuration::Module::SUMMARIZATION,
        )
      end

      it "returns the configured llm model" do
        SiteSetting.ai_summarization_agent = ai_agent.id
        expect(ai_feature.llm_models).to eq([llm_model])
      end
    end

    context "with AI helper module" do
      let(:ai_feature) do
        described_class.new(
          "proofread",
          "ai_helper_proofreader_agent",
          DiscourseAi::Configuration::Module::AI_HELPER_ID,
          DiscourseAi::Configuration::Module::AI_HELPER,
        )
      end

      it "returns the agent's default llm when no specific helper model is set" do
        SiteSetting.ai_helper_proofreader_agent = ai_agent.id
        expect(ai_feature.llm_models).to eq([llm_model])
      end
    end

    context "with translation module" do
      fab!(:translation_model, :llm_model)

      let(:ai_feature) do
        described_class.new(
          "locale_detector",
          "ai_translation_locale_detector_agent",
          DiscourseAi::Configuration::Module::TRANSLATION_ID,
          DiscourseAi::Configuration::Module::TRANSLATION,
        )
      end

      it "uses translation model when configured" do
        SiteSetting.ai_translation_locale_detector_agent = ai_agent.id
        ai_agent.update!(default_llm_id: translation_model.id)
        expect(ai_feature.llm_models).to eq([translation_model])
      end
    end
  end

  describe "#enabled?" do
    it "returns true when no enabled_by_setting is specified" do
      ai_feature =
        described_class.new(
          "topic_summaries",
          "ai_summarization_agent",
          DiscourseAi::Configuration::Module::SUMMARIZATION_ID,
          DiscourseAi::Configuration::Module::SUMMARIZATION,
        )

      expect(ai_feature.enabled?).to be true
    end

    it "respects the enabled_by_setting when specified" do
      ai_feature =
        described_class.new(
          "gists",
          "ai_summary_gists_agent",
          DiscourseAi::Configuration::Module::SUMMARIZATION_ID,
          DiscourseAi::Configuration::Module::SUMMARIZATION,
          enabled_by_setting: "ai_summary_gists_enabled",
        )

      SiteSetting.ai_summary_gists_enabled = false
      expect(ai_feature.enabled?).to be false

      SiteSetting.ai_summary_gists_enabled = true
      expect(ai_feature.enabled?).to be true
    end
  end

  describe ".bot_features" do
    fab!(:bot_llm, :llm_model)
    fab!(:non_bot_llm, :llm_model)

    before { SiteSetting.ai_bot_enabled_llms = bot_llm.id.to_s }

    fab!(:chat_agent) do
      Fabricate(
        :ai_agent,
        default_llm_id: bot_llm.id,
        allow_chat_channel_mentions: true,
        allow_chat_direct_messages: false,
      )
    end
    fab!(:dm_agent) do
      Fabricate(
        :ai_agent,
        default_llm_id: bot_llm.id,
        allow_chat_channel_mentions: false,
        allow_chat_direct_messages: true,
      )
    end
    fab!(:topic_agent) do
      Fabricate(
        :ai_agent,
        default_llm_id: bot_llm.id,
        allow_topic_mentions: true,
        allow_personal_messages: false,
      )
    end
    fab!(:pm_agent) do
      Fabricate(:ai_agent, allow_topic_mentions: false, allow_personal_messages: true)
    end
    fab!(:inactive_agent) do
      Fabricate(
        :ai_agent,
        enabled: false,
        allow_chat_channel_mentions: false,
        allow_chat_direct_messages: false,
        allow_topic_mentions: false,
        allow_personal_messages: true,
      )
    end

    let(:bot_feature) { described_class.bot_features.first }

    it "returns bot features with correct configuration" do
      expect(bot_feature.name).to eq("bot")
      expect(bot_feature.agent_setting).to be_nil
      expect(bot_feature.module_id).to eq(DiscourseAi::Configuration::Module::BOT_ID)
      expect(bot_feature.module_name).to eq(DiscourseAi::Configuration::Module::BOT)
    end

    it "returns only LLMs enabled in ai_bot_enabled_llms setting" do
      # Disable all other agents to ensure only test agents are active
      expected_agent_ids = [chat_agent.id, dm_agent.id, topic_agent.id, pm_agent.id]
      AiAgent.where.not(id: expected_agent_ids).update_all(enabled: false)

      expect(bot_feature.llm_models).to contain_exactly(bot_llm)
      expect(bot_feature.llm_models).not_to include(non_bot_llm)
    end

    it "returns only agents with at least one bot permission enabled" do
      expected_ids = [chat_agent.id, dm_agent.id, topic_agent.id, pm_agent.id]
      AiAgent.where.not(id: expected_ids).update_all(enabled: false)
      expect(bot_feature.agent_ids).to match_array(expected_ids)
      expect(bot_feature.agent_ids).not_to include(inactive_agent.id)
    end

    it "includes agents with multiple permissions enabled" do
      multi_permission_agent =
        Fabricate(
          :ai_agent,
          enabled: true,
          default_llm_id: bot_llm.id,
          allow_chat_channel_mentions: true,
          allow_chat_direct_messages: true,
          allow_topic_mentions: true,
          allow_personal_messages: true,
        )

      expect(bot_feature.agent_ids).to include(multi_permission_agent.id)
    end
  end

  describe "#agent_ids" do
    it "returns the agent id from site settings" do
      ai_feature =
        described_class.new(
          "topic_summaries",
          "ai_summarization_agent",
          DiscourseAi::Configuration::Module::SUMMARIZATION_ID,
          DiscourseAi::Configuration::Module::SUMMARIZATION,
        )

      SiteSetting.ai_summarization_agent = ai_agent.id
      expect(ai_feature.agent_ids).to eq([ai_agent.id])
    end
  end

  describe ".find_features_using" do
    it "returns all features using a specific agent" do
      SiteSetting.ai_summarization_agent = ai_agent.id
      SiteSetting.ai_helper_proofreader_agent = ai_agent.id
      SiteSetting.ai_translation_locale_detector_agent = 999

      features = described_class.find_features_using(agent_id: ai_agent.id)

      expect(features.map(&:name)).to include("topic_summaries", "proofread")
      expect(features.map(&:name)).not_to include("locale_detector")
    end
  end
end
