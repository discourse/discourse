# frozen_string_literal: true

module DiscourseAi
  module Configuration
    class Feature
      class << self
        def feature_cache
          @feature_cache ||= DiscourseAi::MultisiteHash.new("feature_cache")
        end

        def summarization_features
          feature_cache[:summarization] ||= [
            new(
              "topic_summaries",
              "ai_summarization_agent",
              DiscourseAi::Configuration::Module::SUMMARIZATION_ID,
              DiscourseAi::Configuration::Module::SUMMARIZATION,
            ),
            new(
              "gists",
              "ai_summary_gists_agent",
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
              "ai_discover_agent",
              DiscourseAi::Configuration::Module::SEARCH_ID,
              DiscourseAi::Configuration::Module::SEARCH,
              enabled_by_setting: "ai_discover_enabled",
              visible_if: -> { SiteSetting.ai_discover_enabled },
              # Discover is deprecated: once turned off it is hidden and cannot be re-enabled.
              toggleable: false,
            ),
            new(
              "ask_ai",
              "ai_ask_ai_agent",
              DiscourseAi::Configuration::Module::SEARCH_ID,
              DiscourseAi::Configuration::Module::SEARCH,
              enabled_by_setting: "ai_ask_ai_enabled",
              agent_ids_lookup: -> { lookup_ask_ai_agent_ids },
              metadata_lookup: -> do
                decision_model_metadata(DiscourseAi::Discoveries::Intent.decision_model)
              end,
            ),
          ]
        end

        def discord_features
          feature_cache[:discord] ||= [
            new(
              "search",
              "ai_discord_search_agent",
              DiscourseAi::Configuration::Module::DISCORD_ID,
              DiscourseAi::Configuration::Module::DISCORD,
              agentless_if: -> { !DiscourseAi::Discord.agent_mode? },
              metadata_lookup: -> do
                DiscourseAi::Discord.agent_mode? ? {} : { agentless_note: "forum_search" }
              end,
            ),
          ]
        end

        def inference_features
          feature_cache[:inference] ||= [
            new(
              "generate_concepts",
              "inferred_concepts_generate_agent",
              DiscourseAi::Configuration::Module::INFERENCE_ID,
              DiscourseAi::Configuration::Module::INFERENCE,
            ),
            new(
              "match_concepts",
              "inferred_concepts_match_agent",
              DiscourseAi::Configuration::Module::INFERENCE_ID,
              DiscourseAi::Configuration::Module::INFERENCE,
            ),
            new(
              "deduplicate_concepts",
              "inferred_concepts_deduplicate_agent",
              DiscourseAi::Configuration::Module::INFERENCE_ID,
              DiscourseAi::Configuration::Module::INFERENCE,
            ),
          ]
        end

        def ai_helper_features
          feature_cache[:ai_helper] ||= [
            new(
              "proofread",
              "ai_helper_proofreader_agent",
              DiscourseAi::Configuration::Module::AI_HELPER_ID,
              DiscourseAi::Configuration::Module::AI_HELPER,
              access_by_agent_groups: true,
            ),
            new(
              "title_suggestions",
              "ai_helper_title_suggestions_agent",
              DiscourseAi::Configuration::Module::AI_HELPER_ID,
              DiscourseAi::Configuration::Module::AI_HELPER,
              access_by_agent_groups: true,
            ),
            new(
              "explain",
              "ai_helper_explain_agent",
              DiscourseAi::Configuration::Module::AI_HELPER_ID,
              DiscourseAi::Configuration::Module::AI_HELPER,
              access_by_agent_groups: true,
            ),
            new(
              "smart_dates",
              "ai_helper_smart_dates_agent",
              DiscourseAi::Configuration::Module::AI_HELPER_ID,
              DiscourseAi::Configuration::Module::AI_HELPER,
              access_by_agent_groups: true,
            ),
            new(
              "markdown_tables",
              "ai_helper_markdown_tables_agent",
              DiscourseAi::Configuration::Module::AI_HELPER_ID,
              DiscourseAi::Configuration::Module::AI_HELPER,
              access_by_agent_groups: true,
            ),
            new(
              "translator",
              "ai_helper_translator_agent",
              DiscourseAi::Configuration::Module::AI_HELPER_ID,
              DiscourseAi::Configuration::Module::AI_HELPER,
              access_by_agent_groups: true,
            ),
            new(
              "custom_prompt",
              "ai_helper_custom_prompt_agent",
              DiscourseAi::Configuration::Module::AI_HELPER_ID,
              DiscourseAi::Configuration::Module::AI_HELPER,
              access_by_agent_groups: true,
            ),
            new(
              "post_illustrator",
              "ai_helper_post_illustrator_agent",
              DiscourseAi::Configuration::Module::AI_HELPER_ID,
              DiscourseAi::Configuration::Module::AI_HELPER,
              access_by_agent_groups: true,
              metadata_lookup: -> do
                tools =
                  AiAgent.find_by(
                    id: SiteSetting.ai_helper_post_illustrator_agent,
                  )&.automatic_image_tools
                tools.nil? ? {} : { automatic_image_tools: tools }
              end,
              setup_note_lookup: -> do
                agent = AiAgent.find_by(id: SiteSetting.ai_helper_post_illustrator_agent)
                "no_image_generation_tool" if !agent&.has_image_generation_tool?
              end,
            ),
            new(
              "chat_thread_titles",
              "ai_helper_chat_thread_title_agent",
              DiscourseAi::Configuration::Module::AI_HELPER_ID,
              DiscourseAi::Configuration::Module::AI_HELPER,
              enabled_by_setting: "ai_helper_automatic_chat_thread_title",
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
              agent_ids_lookup: -> { lookup_bot_agent_ids },
              llm_models_lookup: -> { lookup_bot_llms },
              metadata_lookup: -> { { chatbot_agents: chatbot_agents_metadata } },
            ),
          ]
        end

        def image_caption_features
          feature_cache[:image_caption] ||= [
            new(
              "post_image_captions",
              "ai_image_caption_agent",
              DiscourseAi::Configuration::Module::IMAGE_CAPTION_ID,
              DiscourseAi::Configuration::Module::IMAGE_CAPTION,
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
              agent_ids_lookup: -> { [AiModerationSetting.spam&.ai_agent_id].compact },
              llm_models_lookup: -> { [AiModerationSetting.spam&.llm_model].compact },
            ),
          ]
        end

        def embeddings_features
          feature_cache[:embeddings] ||= [
            new(
              "related_topics",
              nil,
              DiscourseAi::Configuration::Module::EMBEDDINGS_ID,
              DiscourseAi::Configuration::Module::EMBEDDINGS,
              enabled_by_setting: "ai_embeddings_semantic_related_topics_enabled",
            ),
            new(
              "semantic_search",
              nil,
              DiscourseAi::Configuration::Module::EMBEDDINGS_ID,
              DiscourseAi::Configuration::Module::EMBEDDINGS,
              enabled_by_setting: "ai_embeddings_semantic_search_enabled",
            ),
            new(
              "quick_search",
              nil,
              DiscourseAi::Configuration::Module::EMBEDDINGS_ID,
              DiscourseAi::Configuration::Module::EMBEDDINGS,
              enabled_by_setting: "ai_embeddings_semantic_quick_search_enabled",
            ),
            new(
              "hyde",
              "ai_embeddings_semantic_search_hyde_agent",
              DiscourseAi::Configuration::Module::EMBEDDINGS_ID,
              DiscourseAi::Configuration::Module::EMBEDDINGS,
              enabled_by_setting: "ai_embeddings_semantic_search_use_hyde",
            ),
          ]
        end

        def admin_dashboard_features
          feature_cache[:admin_dashboard] ||= [
            new(
              "highlights",
              "ai_admin_dashboard_highlights_agent",
              DiscourseAi::Configuration::Module::ADMIN_DASHBOARD_ID,
              DiscourseAi::Configuration::Module::ADMIN_DASHBOARD,
              enabled_by_setting: "ai_admin_dashboard_enabled",
              require_enabled_agent: true,
            ),
          ]
        end

        def sentiment_features
          feature_cache[:sentiment] ||= %w[sentiment emotion].map do |type|
            summary = -> { DiscourseAi::Sentiment::PostClassification.classifier_summary_for(type) }

            new(
              type,
              "ai_sentiment_#{type}_agent",
              DiscourseAi::Configuration::Module::SENTIMENT_ID,
              DiscourseAi::Configuration::Module::SENTIMENT,
              enabled_by_setting:
                type == "sentiment" ? "ai_sentiment_enabled" : "ai_sentiment_emotion_enabled",
              agent_ids_lookup: -> { summary.call.fetch(:agent_ids, []) },
              llm_models_lookup: -> { summary.call.fetch(:llm_models, []) },
              metadata_lookup: -> do
                summary.call.slice(:backend, :ready, :decision_model, :classification_model)
              end,
            )
          end
        end

        # Agents people can talk to, matching what the chatbot offers: it needs a bot user.
        def lookup_bot_agent_ids
          AiAgent
            .where(enabled: true)
            .where.not(user_id: nil)
            .where.not(id: SiteSetting.ai_image_caption_agent.to_i)
            .where(
              "allow_chat_channel_mentions OR allow_chat_direct_messages OR allow_topic_mentions OR allow_personal_messages",
            )
            .pluck(:id)
        end

        # Every enabled agent that could be a chatbot, with where people can reach it.
        def chatbot_agents_metadata
          agents =
            AiAgent
              .where(enabled: true)
              .where.not(id: SiteSetting.ai_image_caption_agent.to_i)
              .order(:name)
              .select(&:supports_bot_user?)
          chatbot_ids = lookup_bot_agent_ids.to_set
          group_names =
            Group.where(id: agents.flat_map(&:allowed_group_ids).uniq).pluck(:id, :name).to_h
          llm_names =
            LlmModel.where(id: agents.filter_map(&:default_llm_id)).pluck(:id, :display_name).to_h

          agents.map do |agent|
            {
              id: agent.id,
              name: agent.name,
              chatbot: chatbot_ids.include?(agent.id),
              personal_messages: agent.allow_personal_messages,
              topic_mentions: agent.allow_topic_mentions,
              chat_direct_messages: agent.allow_chat_direct_messages,
              chat_channel_mentions: agent.allow_chat_channel_mentions,
              allowed_groups:
                agent.allowed_group_ids.filter_map do |id|
                  { id:, name: group_names[id] } if group_names[id]
                end,
              llm:
                if (name = llm_names[agent.default_llm_id])
                  { id: agent.default_llm_id, name: }
                end,
            }
          end
        end

        # A decision model that works alongside the feature's agents, which still handle what it
        # cannot decide.
        def decision_model_metadata(decision_model)
          return {} if decision_model.blank?

          { decision_model: { id: decision_model.id, display_name: decision_model.display_name } }
        end

        def lookup_ask_ai_agent_ids
          [
            SiteSetting.ai_ask_ai_agent,
            SiteSetting.ai_ask_ai_query_rewriter_agent,
            SiteSetting.ai_ask_ai_report_agent,
            SiteSetting.ai_ask_ai_follow_up_agent,
          ].map(&:to_i).reject(&:zero?).uniq
        end

        def lookup_bot_llms
          agent_llms = AiAgent.where(id: lookup_bot_agent_ids).pluck(:default_llm_id)
          enabled_chat_bot_llm_ids = LlmModel.enabled_chat_bot_ids

          LlmModel.where(id: (agent_llms + enabled_chat_bot_llm_ids).uniq).to_a
        end

        def translation_features
          feature_cache[:translation] ||= [
            new(
              "locale_detector",
              "ai_translation_locale_detector_agent",
              DiscourseAi::Configuration::Module::TRANSLATION_ID,
              DiscourseAi::Configuration::Module::TRANSLATION,
              metadata_lookup: -> do
                decision_model_metadata(
                  DiscourseAi::Translation::DecisionLocaleDetector.decision_model,
                )
              end,
            ),
            new(
              "post_raw_translator",
              "ai_translation_post_raw_translator_agent",
              DiscourseAi::Configuration::Module::TRANSLATION_ID,
              DiscourseAi::Configuration::Module::TRANSLATION,
            ),
            new(
              "topic_title_translator",
              "ai_translation_topic_title_translator_agent",
              DiscourseAi::Configuration::Module::TRANSLATION_ID,
              DiscourseAi::Configuration::Module::TRANSLATION,
            ),
            new(
              "short_text_translator",
              "ai_translation_short_text_translator_agent",
              DiscourseAi::Configuration::Module::TRANSLATION_ID,
              DiscourseAi::Configuration::Module::TRANSLATION,
            ),
          ]
        end

        def ai_automation_report_scripts
          return [] if !SiteSetting.discourse_automation_enabled

          feature_cache[:automation_reports] ||= begin
            all_script_fields = DB.query(<<~SQL)
              SELECT (fields.metadata->>'value') AS value, automations.name AS automation_name, fields.name AS name
              FROM discourse_automation_fields fields
              INNER JOIN discourse_automation_automations automations ON automations.id = fields.automation_id
              WHERE fields.name IN ('model', 'agent_id')
              AND automations.script = 'llm_report'
              AND automations.enabled
              LIMIT 20
            SQL

            all_script_fields =
              all_script_fields
                .take(10)
                .reduce({}) do |memo, field|
                  memo[field.automation_name] = {} if memo[field.automation_name].nil?

                  memo[field.automation_name][field.name] = field.value

                  memo
                end

            all_script_fields.map do |automation_name, fields|
              new(
                automation_name,
                nil,
                DiscourseAi::Configuration::Module::AUTOMATION_REPORTS_ID,
                DiscourseAi::Configuration::Module::AUTOMATION_REPORTS,
                agent_ids_lookup: -> { [fields.dig("agent_id")].compact.map(&:to_i) },
                llm_models_lookup: -> { [LlmModel.find_by(id: fields["model"])].compact },
              )
            end
          end
        end

        def ai_automation_triage_scripts
          return [] if !SiteSetting.discourse_automation_enabled

          feature_cache[:automation_triage] ||= begin
            all_script_fields = DB.query(<<~SQL)
            SELECT (fields.metadata->>'value') AS value, automations.name AS automation_name, fields.name AS name
            FROM discourse_automation_fields fields
            INNER JOIN discourse_automation_automations automations ON automations.id = fields.automation_id
            WHERE fields.name IN ('model', 'triage_agent', 'agent')
            AND automations.script IN ('llm_triage', 'llm_agent_triage')
            AND automations.enabled
            LIMIT 20
          SQL

            all_script_fields =
              all_script_fields.reduce({}) do |memo, field|
                memo[field.automation_name] = {} if memo[field.automation_name].nil?

                if field.name == "model"
                  memo[field.automation_name][field.name] = field.value
                else
                  memo[field.automation_name]["agent_id"] = field.value
                end

                memo
              end

            all_script_fields
              .take(10)
              .map do |automation_name, field|
                llm_models_lookup =
                  if field["model"].present?
                    -> { [LlmModel.find_by(id: field["model"])].compact }
                  else
                    nil # llm_agent_triage uses the agent default_llm_id.
                  end

                new(
                  automation_name,
                  nil,
                  DiscourseAi::Configuration::Module::AUTOMATION_TRIAGE_ID,
                  DiscourseAi::Configuration::Module::AUTOMATION_TRIAGE,
                  agent_ids_lookup: -> { [field.dig("agent_id")].compact.map(&:to_i) },
                  llm_models_lookup: llm_models_lookup,
                )
              end
          end
        end

        def all
          base = [
            summarization_features,
            search_features,
            discord_features,
            inference_features,
            ai_helper_features,
            image_caption_features,
            translation_features,
            bot_features,
            spam_features,
            embeddings_features,
            admin_dashboard_features,
            sentiment_features,
            ai_automation_report_scripts,
            ai_automation_triage_scripts,
          ].flatten

          # external features from plugin registry
          DiscoursePluginRegistry.external_ai_features.each do |entry|
            module_id = DiscourseAi::Configuration::Module.external_module_id(entry[:module_name])
            setting_name = "#{entry[:module_name]}_#{entry[:feature]}_agent"
            base << new(
              entry[:feature].to_s,
              setting_name,
              module_id,
              entry[:module_name].to_s,
              enabled_by_setting: entry[:enabled_by_setting],
              metadata_lookup: -> do
                entry[:entry_point] ? { entry_point: entry[:entry_point] } : {}
              end,
            )
          end

          base
        end

        def find_features_using(agent_id:)
          all.select { |feature| feature.agent_ids.include?(agent_id) }
        end
      end

      def initialize(
        name,
        agent_setting,
        module_id,
        module_name,
        enabled_by_setting: "",
        agent_ids_lookup: nil,
        llm_models_lookup: nil,
        metadata_lookup: nil,
        require_enabled_agent: false,
        visible_if: nil,
        toggleable: true,
        access_by_agent_groups: false,
        setup_note_lookup: nil,
        agentless_if: nil
      )
        @name = name
        @agent_setting = agent_setting
        @module_id = module_id
        @module_name = module_name
        @enabled_by_setting = enabled_by_setting
        @agent_ids_lookup = agent_ids_lookup
        @llm_models_lookup = llm_models_lookup
        @metadata_lookup = metadata_lookup
        @require_enabled_agent = require_enabled_agent
        @visible_if = visible_if
        @toggleable = toggleable
        @access_by_agent_groups = access_by_agent_groups
        @setup_note_lookup = setup_note_lookup
        @agentless_if = agentless_if
      end

      def metadata
        @metadata_lookup ? @metadata_lookup.call : {}
      end

      def llm_models
        return @llm_models_lookup.call if @llm_models_lookup
        return if !agent_ids

        llm_models = []
        agents = AiAgent.where(id: agent_ids)
        agents.each do |agent|
          next if agent.blank?

          agent_klass = agent.class_instance

          llm_model =
            case module_name
            when DiscourseAi::Configuration::Module::SUMMARIZATION
              DiscourseAi::Summarization.find_summarization_model(agent_klass)
            when DiscourseAi::Configuration::Module::AI_HELPER
              DiscourseAi::AiHelper::Assistant.find_ai_helper_model(name, agent_klass)
            when DiscourseAi::Configuration::Module::IMAGE_CAPTION
              DiscourseAi::PostImageCaptions.image_caption_llm_model(agent)
            when DiscourseAi::Configuration::Module::TRANSLATION
              DiscourseAi::Translation::BaseTranslator.preferred_llm_model(agent_klass)
            when DiscourseAi::Configuration::Module::EMBEDDINGS
              DiscourseAi::Embeddings::SemanticSearch.new(nil).find_ai_hyde_model(agent_klass)
            end

          if llm_model.blank?
            llm_model_id = agent.default_llm_id || SiteSetting.ai_default_llm_model
            llm_model = LlmModel.find_by(id: llm_model_id)
          end

          llm_models << llm_model if llm_model
        end

        llm_models.compact.uniq
      end

      attr_reader :name, :agent_setting, :module_id, :module_name

      def visible?
        @visible_if.blank? || @visible_if.call
      end

      def toggle_setting
        @enabled_by_setting.presence if @toggleable
      end

      # Whether the feature works without an agent, such as embeddings lookups.
      def agentless?
        return @agentless_if.call if @agentless_if

        agent_setting.blank? && @agent_ids_lookup.nil? && @metadata_lookup.nil?
      end

      # Whether users can only use the feature when they are in its agent's allowed groups.
      def access_by_agent_groups?
        @access_by_agent_groups
      end

      # @return [String, nil] why the feature cannot work until something else is set up
      def setup_note
        @setup_note_lookup&.call
      end

      def enabled?
        return false if setup_note.present?
        return false if access_by_agent_groups? && !agents_have_allowed_groups?
        return agent_enabled? if @enabled_by_setting.blank?
        return false unless SiteSetting.respond_to?(@enabled_by_setting)
        return false if !SiteSetting.get(@enabled_by_setting)

        agent_enabled?
      end

      def agents_have_allowed_groups?
        agent_ids.any? do |agent_id|
          AiAgent.find_by_id_from_cache(agent_id)&.allowed_group_ids.present?
        end
      end

      def agent_enabled?
        return true if !@require_enabled_agent
        agent_ids.any? { |agent_id| AiAgent.find_by_id_from_cache(agent_id)&.enabled? }
      end

      def agent_ids
        if @agent_ids_lookup
          @agent_ids_lookup.call
        else
          return [] if agent_setting.blank? || !SiteSetting.respond_to?(agent_setting)
          id = SiteSetting.get(agent_setting).to_i
          id != 0 ? [id] : []
        end
      end
    end
  end
end
