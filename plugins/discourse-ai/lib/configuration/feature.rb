# frozen_string_literal: true

module DiscourseAi
  module Configuration
    class Feature
      class << self
        def feature_cache
          @feature_cache ||= ::DiscourseAi::MultisiteHash.new("feature_cache")
        end

        def summarization_features
          feature_cache[:summarization] ||= [
            new(
              "topic_summaries",
              "ai_summarization_persona",
              DiscourseAi::Configuration::Module::SUMMARIZATION_ID,
              DiscourseAi::Configuration::Module::SUMMARIZATION,
            ),
            new(
              "gists",
              "ai_summary_gists_persona",
              DiscourseAi::Configuration::Module::SUMMARIZATION_ID,
              DiscourseAi::Configuration::Module::SUMMARIZATION,
              enabled_by_setting: "ai_summary_gists_enabled",
            ),
          ]
        end

        def search_features
          feature_cache[:search] ||= [
            new(
              "discoveries",
              "ai_bot_discover_persona",
              DiscourseAi::Configuration::Module::SEARCH_ID,
              DiscourseAi::Configuration::Module::SEARCH,
            ),
          ]
        end

        def discord_features
          feature_cache[:discord] ||= [
            new(
              "search",
              "ai_discord_search_persona",
              DiscourseAi::Configuration::Module::DISCORD_ID,
              DiscourseAi::Configuration::Module::DISCORD,
            ),
          ]
        end

        def inference_features
          feature_cache[:inference] ||= [
            new(
              "generate_concepts",
              "inferred_concepts_generate_persona",
              DiscourseAi::Configuration::Module::INFERENCE_ID,
              DiscourseAi::Configuration::Module::INFERENCE,
            ),
            new(
              "match_concepts",
              "inferred_concepts_match_persona",
              DiscourseAi::Configuration::Module::INFERENCE_ID,
              DiscourseAi::Configuration::Module::INFERENCE,
            ),
            new(
              "deduplicate_concepts",
              "inferred_concepts_deduplicate_persona",
              DiscourseAi::Configuration::Module::INFERENCE_ID,
              DiscourseAi::Configuration::Module::INFERENCE,
            ),
          ]
        end

        def ai_helper_features
          feature_cache[:ai_helper] ||= [
            new(
              "proofread",
              "ai_helper_proofreader_persona",
              DiscourseAi::Configuration::Module::AI_HELPER_ID,
              DiscourseAi::Configuration::Module::AI_HELPER,
            ),
            new(
              "title_suggestions",
              "ai_helper_title_suggestions_persona",
              DiscourseAi::Configuration::Module::AI_HELPER_ID,
              DiscourseAi::Configuration::Module::AI_HELPER,
            ),
            new(
              "explain",
              "ai_helper_explain_persona",
              DiscourseAi::Configuration::Module::AI_HELPER_ID,
              DiscourseAi::Configuration::Module::AI_HELPER,
            ),
            new(
              "smart_dates",
              "ai_helper_smart_dates_persona",
              DiscourseAi::Configuration::Module::AI_HELPER_ID,
              DiscourseAi::Configuration::Module::AI_HELPER,
            ),
            new(
              "markdown_tables",
              "ai_helper_markdown_tables_persona",
              DiscourseAi::Configuration::Module::AI_HELPER_ID,
              DiscourseAi::Configuration::Module::AI_HELPER,
            ),
            new(
              "translator",
              "ai_helper_translator_persona",
              DiscourseAi::Configuration::Module::AI_HELPER_ID,
              DiscourseAi::Configuration::Module::AI_HELPER,
            ),
            new(
              "custom_prompt",
              "ai_helper_custom_prompt_persona",
              DiscourseAi::Configuration::Module::AI_HELPER_ID,
              DiscourseAi::Configuration::Module::AI_HELPER,
            ),
            new(
              "image_caption",
              "ai_helper_image_caption_persona",
              DiscourseAi::Configuration::Module::AI_HELPER_ID,
              DiscourseAi::Configuration::Module::AI_HELPER,
            ),
          ]
        end

        def bot_features
          feature_cache[:bot] ||= [
            new(
              "bot",
              nil,
              DiscourseAi::Configuration::Module::BOT_ID,
              DiscourseAi::Configuration::Module::BOT,
              persona_ids_lookup: -> { lookup_bot_persona_ids },
              llm_models_lookup: -> { lookup_bot_llms },
            ),
          ]
        end

        def spam_features
          feature_cache[:spam] ||= [
            new(
              "inspect_posts",
              nil,
              DiscourseAi::Configuration::Module::SPAM_ID,
              DiscourseAi::Configuration::Module::SPAM,
              persona_ids_lookup: -> { [AiModerationSetting.spam&.ai_persona_id].compact },
              llm_models_lookup: -> { [AiModerationSetting.spam&.llm_model].compact },
            ),
          ]
        end

        def embeddings_features
          feature_cache[:embeddings] ||= [
            new(
              "hyde",
              "ai_embeddings_semantic_search_hyde_persona",
              DiscourseAi::Configuration::Module::EMBEDDINGS_ID,
              DiscourseAi::Configuration::Module::EMBEDDINGS,
            ),
          ]
        end

        def lookup_bot_persona_ids
          AiPersona
            .where(enabled: true)
            .where(
              "allow_chat_channel_mentions OR allow_chat_direct_messages OR allow_topic_mentions OR allow_personal_messages",
            )
            .pluck(:id)
        end

        def lookup_bot_llms
          LlmModel.where(enabled_chat_bot: true).to_a
        end

        def translation_features
          feature_cache[:translation] ||= [
            new(
              "locale_detector",
              "ai_translation_locale_detector_persona",
              DiscourseAi::Configuration::Module::TRANSLATION_ID,
              DiscourseAi::Configuration::Module::TRANSLATION,
            ),
            new(
              "post_raw_translator",
              "ai_translation_post_raw_translator_persona",
              DiscourseAi::Configuration::Module::TRANSLATION_ID,
              DiscourseAi::Configuration::Module::TRANSLATION,
            ),
            new(
              "topic_title_translator",
              "ai_translation_topic_title_translator_persona",
              DiscourseAi::Configuration::Module::TRANSLATION_ID,
              DiscourseAi::Configuration::Module::TRANSLATION,
            ),
            new(
              "short_text_translator",
              "ai_translation_short_text_translator_persona",
              DiscourseAi::Configuration::Module::TRANSLATION_ID,
              DiscourseAi::Configuration::Module::TRANSLATION,
            ),
          ]
        end

        def all
          [
            summarization_features,
            search_features,
            discord_features,
            inference_features,
            ai_helper_features,
            translation_features,
            bot_features,
            spam_features,
            embeddings_features,
          ].flatten
        end

        def find_features_using(persona_id:)
          all.select { |feature| feature.persona_ids.include?(persona_id) }
        end
      end

      def initialize(
        name,
        persona_setting,
        module_id,
        module_name,
        enabled_by_setting: "",
        persona_ids_lookup: nil,
        llm_models_lookup: nil
      )
        @name = name
        @persona_setting = persona_setting
        @module_id = module_id
        @module_name = module_name
        @enabled_by_setting = enabled_by_setting
        @persona_ids_lookup = persona_ids_lookup
        @llm_models_lookup = llm_models_lookup
      end

      def llm_models
        return @llm_models_lookup.call if @llm_models_lookup
        return if !persona_ids

        llm_models = []
        personas = AiPersona.where(id: persona_ids)
        personas.each do |persona|
          next if persona.blank?

          persona_klass = persona.class_instance

          llm_model =
            case module_name
            when DiscourseAi::Configuration::Module::SUMMARIZATION
              DiscourseAi::Summarization.find_summarization_model(persona_klass)
            when DiscourseAi::Configuration::Module::AI_HELPER
              DiscourseAi::AiHelper::Assistant.find_ai_helper_model(name, persona_klass)
            when DiscourseAi::Configuration::Module::TRANSLATION
              DiscourseAi::Translation::BaseTranslator.preferred_llm_model(persona_klass)
            when DiscourseAi::Configuration::Module::EMBEDDINGS
              DiscourseAi::Embeddings::SemanticSearch.new(nil).find_ai_hyde_model(persona_klass)
            end

          if llm_model.blank? && persona.default_llm_id
            llm_model = LlmModel.find_by(id: persona.default_llm_id)
          end

          llm_models << llm_model if llm_model
        end

        llm_models.compact.uniq
      end

      attr_reader :name, :persona_setting, :module_id, :module_name

      def enabled?
        @enabled_by_setting.blank? || SiteSetting.get(@enabled_by_setting)
      end

      def persona_ids
        if @persona_ids_lookup
          @persona_ids_lookup.call
        else
          id = SiteSetting.get(persona_setting).to_i
          if id != 0
            [id]
          else
            []
          end
        end
      end
    end
  end
end
