# frozen_string_literal: true

RSpec.describe DiscourseAi::Configuration::Feature do
  fab!(:llm_model)
  fab!(:ai_persona) { Fabricate(:ai_persona, default_llm_id: llm_model.id) }

  before { assign_fake_provider_to(:ai_default_llm_model) }

  def allow_configuring_setting(&block)
    DiscourseAi::Completions::Llm.with_prepared_responses(["OK"]) { block.call }
  end

  before { enable_current_plugin }

  describe "#llm_model" do
    context "when persona is not found" do
      it "returns nil when persona_id is invalid" do
        ai_feature =
          described_class.new(
            "topic_summaries",
            "ai_summarization_persona",
            DiscourseAi::Configuration::Module::SUMMARIZATION_ID,
            DiscourseAi::Configuration::Module::SUMMARIZATION,
          )

        SiteSetting.ai_summarization_persona = 999_999
        expect(ai_feature.llm_models).to eq([])
      end
    end

    context "with summarization module" do
      let(:ai_feature) do
        described_class.new(
          "topic_summaries",
          "ai_summarization_persona",
          DiscourseAi::Configuration::Module::SUMMARIZATION_ID,
          DiscourseAi::Configuration::Module::SUMMARIZATION,
        )
      end

      it "returns the configured llm model" do
        SiteSetting.ai_summarization_persona = ai_persona.id
        expect(ai_feature.llm_models).to eq([llm_model])
      end
    end

    context "with AI helper module" do
      let(:ai_feature) do
        described_class.new(
          "proofread",
          "ai_helper_proofreader_persona",
          DiscourseAi::Configuration::Module::AI_HELPER_ID,
          DiscourseAi::Configuration::Module::AI_HELPER,
        )
      end

      it "returns the persona's default llm when no specific helper model is set" do
        SiteSetting.ai_helper_proofreader_persona = ai_persona.id
        expect(ai_feature.llm_models).to eq([llm_model])
      end
    end

    context "with translation module" do
      fab!(:translation_model, :llm_model)

      let(:ai_feature) do
        described_class.new(
          "locale_detector",
          "ai_translation_locale_detector_persona",
          DiscourseAi::Configuration::Module::TRANSLATION_ID,
          DiscourseAi::Configuration::Module::TRANSLATION,
        )
      end

      it "uses translation model when configured" do
        SiteSetting.ai_translation_locale_detector_persona = ai_persona.id
        ai_persona.update!(default_llm_id: translation_model.id)
        expect(ai_feature.llm_models).to eq([translation_model])
      end
    end
  end

  describe "#enabled?" do
    it "returns true when no enabled_by_setting is specified" do
      ai_feature =
        described_class.new(
          "topic_summaries",
          "ai_summarization_persona",
          DiscourseAi::Configuration::Module::SUMMARIZATION_ID,
          DiscourseAi::Configuration::Module::SUMMARIZATION,
        )

      expect(ai_feature.enabled?).to be true
    end

    it "respects the enabled_by_setting when specified" do
      ai_feature =
        described_class.new(
          "gists",
          "ai_summary_gists_persona",
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
    fab!(:bot_llm) { Fabricate(:llm_model, enabled_chat_bot: true) }
    fab!(:non_bot_llm) { Fabricate(:llm_model, enabled_chat_bot: false) }
    fab!(:chat_persona) do
      Fabricate(
        :ai_persona,
        default_llm_id: bot_llm.id,
        allow_chat_channel_mentions: true,
        allow_chat_direct_messages: false,
      )
    end
    fab!(:dm_persona) do
      Fabricate(
        :ai_persona,
        default_llm_id: bot_llm.id,
        allow_chat_channel_mentions: false,
        allow_chat_direct_messages: true,
      )
    end
    fab!(:topic_persona) do
      Fabricate(
        :ai_persona,
        default_llm_id: bot_llm.id,
        allow_topic_mentions: true,
        allow_personal_messages: false,
      )
    end
    fab!(:pm_persona) do
      Fabricate(:ai_persona, allow_topic_mentions: false, allow_personal_messages: true)
    end
    fab!(:inactive_persona) do
      Fabricate(
        :ai_persona,
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
      expect(bot_feature.persona_setting).to be_nil
      expect(bot_feature.module_id).to eq(DiscourseAi::Configuration::Module::BOT_ID)
      expect(bot_feature.module_name).to eq(DiscourseAi::Configuration::Module::BOT)
    end

    it "returns only LLMs with enabled_chat_bot" do
      expect(bot_feature.llm_models).to contain_exactly(bot_llm)
      expect(bot_feature.llm_models).not_to include(non_bot_llm)
    end

    it "returns only personas with at least one bot permission enabled" do
      expected_ids = [chat_persona.id, dm_persona.id, topic_persona.id, pm_persona.id]
      AiPersona.where.not(id: expected_ids).update_all(enabled: false)
      expect(bot_feature.persona_ids).to match_array(expected_ids)
      expect(bot_feature.persona_ids).not_to include(inactive_persona.id)
    end

    it "includes personas with multiple permissions enabled" do
      multi_permission_persona =
        Fabricate(
          :ai_persona,
          enabled: true,
          default_llm_id: bot_llm.id,
          allow_chat_channel_mentions: true,
          allow_chat_direct_messages: true,
          allow_topic_mentions: true,
          allow_personal_messages: true,
        )

      expect(bot_feature.persona_ids).to include(multi_permission_persona.id)
    end
  end

  describe "#persona_ids" do
    it "returns the persona id from site settings" do
      ai_feature =
        described_class.new(
          "topic_summaries",
          "ai_summarization_persona",
          DiscourseAi::Configuration::Module::SUMMARIZATION_ID,
          DiscourseAi::Configuration::Module::SUMMARIZATION,
        )

      SiteSetting.ai_summarization_persona = ai_persona.id
      expect(ai_feature.persona_ids).to eq([ai_persona.id])
    end
  end

  describe ".find_features_using" do
    it "returns all features using a specific persona" do
      SiteSetting.ai_summarization_persona = ai_persona.id
      SiteSetting.ai_helper_proofreader_persona = ai_persona.id
      SiteSetting.ai_translation_locale_detector_persona = 999

      features = described_class.find_features_using(persona_id: ai_persona.id)

      expect(features.map(&:name)).to include("topic_summaries", "proofread")
      expect(features.map(&:name)).not_to include("locale_detector")
    end
  end
end
