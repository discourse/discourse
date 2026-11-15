# frozen_string_literal: true

module DiscourseAi
  module Configuration
    class Module
      SUMMARIZATION = "summarization"
      SEARCH = "search"
      DISCORD = "discord"
      INFERENCE = "inference"
      AI_HELPER = "ai_helper"
      IMAGE_CAPTION = "image_caption"
      TRANSLATION = "translation"
      BOT = "bot"
      SPAM = "spam"
      EMBEDDINGS = "embeddings"
      AUTOMATION_REPORTS = "automation_reports"
      AUTOMATION_TRIAGE = "automation_triage"
      ADMIN_DASHBOARD = "admin_dashboard"
      SENTIMENT = "sentiment"

      NAMES = [
        SUMMARIZATION,
        SEARCH,
        DISCORD,
        INFERENCE,
        AI_HELPER,
        IMAGE_CAPTION,
        TRANSLATION,
        BOT,
        SPAM,
        EMBEDDINGS,
        AUTOMATION_REPORTS,
        AUTOMATION_TRIAGE,
        ADMIN_DASHBOARD,
        SENTIMENT,
      ].freeze

      SUMMARIZATION_ID = 1
      SEARCH_ID = 2
      DISCORD_ID = 3
      INFERENCE_ID = 4
      AI_HELPER_ID = 5
      TRANSLATION_ID = 6
      BOT_ID = 7
      SPAM_ID = 8
      EMBEDDINGS_ID = 9
      AUTOMATION_REPORTS_ID = 10
      AUTOMATION_TRIAGE_ID = 11
      ADMIN_DASHBOARD_ID = 12
      IMAGE_CAPTION_ID = 13
      SENTIMENT_ID = 14

      class << self
        def external_module_id(module_name)
          Digest::SHA1.hexdigest(module_name.to_s).to_i(16) % 100_000 + 1000
        end

        def all
          base_modules = [
            new(
              SUMMARIZATION_ID,
              SUMMARIZATION,
              enabled_by_setting: "ai_summarization_enabled",
              features: DiscourseAi::Configuration::Feature.summarization_features,
            ),
            new(
              SEARCH_ID,
              SEARCH,
              features: DiscourseAi::Configuration::Feature.search_features,
              extra_check: -> { SiteSetting.ai_discover_enabled || SiteSetting.ai_ask_ai_enabled },
            ),
            new(
              DISCORD_ID,
              DISCORD,
              enabled_by_setting: "ai_discord_search_enabled",
              features: DiscourseAi::Configuration::Feature.discord_features,
              extra_check: -> { DiscourseAi::Discord.missing_setup.empty? },
              setup_check: -> { DiscourseAi::Discord.missing_setup.empty? },
              status_lookup: -> { DiscourseAi::Discord.admin_status },
            ),
            new(
              INFERENCE_ID,
              INFERENCE,
              enabled_by_setting: "inferred_concepts_enabled",
              features: DiscourseAi::Configuration::Feature.inference_features,
              # Nothing displays the concepts yet, so admins would pay for output they cannot see.
              visible: false,
            ),
            new(
              AI_HELPER_ID,
              AI_HELPER,
              enabled_by_setting: "ai_helper_enabled",
              features: DiscourseAi::Configuration::Feature.ai_helper_features,
            ),
            new(
              IMAGE_CAPTION_ID,
              IMAGE_CAPTION,
              enabled_by_setting: "ai_post_image_captions_enabled",
              features: DiscourseAi::Configuration::Feature.image_caption_features,
            ),
            new(
              TRANSLATION_ID,
              TRANSLATION,
              enabled_by_setting: "ai_translation_enabled",
              features: DiscourseAi::Configuration::Feature.translation_features,
              extra_check: -> { DiscourseAi::Translation.enabled? },
              setup_check: -> { SiteSetting.content_localization_supported_locales.present? },
              status_lookup: -> { DiscourseAi::Translation.admin_status },
            ),
            new(
              BOT_ID,
              BOT,
              enabled_by_setting: "ai_bot_enabled",
              features: DiscourseAi::Configuration::Feature.bot_features,
              status_lookup: -> do
                if SiteSetting.ai_bot_enabled
                  {
                    state: "on",
                    label_key: "on_with_chatbot_agents",
                    count: DiscourseAi::Configuration::Feature.lookup_bot_agent_ids.size,
                  }
                end
              end,
            ),
            new(
              SPAM_ID,
              SPAM,
              enabled_by_setting: "ai_spam_detection_enabled",
              features: DiscourseAi::Configuration::Feature.spam_features,
            ),
            new(
              EMBEDDINGS_ID,
              EMBEDDINGS,
              enabled_by_setting: "ai_embeddings_enabled",
              features: DiscourseAi::Configuration::Feature.embeddings_features,
              extra_check: -> { DiscourseAi::Embeddings.enabled? },
              status_lookup: -> { DiscourseAi::Embeddings.admin_status },
              model_names_lookup: -> do
                EmbeddingDefinition.where(
                  id: SiteSetting.ai_embeddings_selected_model.presence,
                ).pluck(:display_name)
              end,
            ),
            new(
              ADMIN_DASHBOARD_ID,
              ADMIN_DASHBOARD,
              enabled_by_setting: "ai_admin_dashboard_enabled",
              features: DiscourseAi::Configuration::Feature.admin_dashboard_features,
              extra_check: -> do
                DiscourseAi::Configuration::Feature.admin_dashboard_features.any?(&:enabled?)
              end,
              visible: false,
            ),
            new(
              SENTIMENT_ID,
              SENTIMENT,
              features: DiscourseAi::Configuration::Feature.sentiment_features,
              extra_check: -> { DiscourseAi::Sentiment::PostClassification.any_enabled? },
            ),
          ]

          if SiteSetting.discourse_automation_enabled
            base_modules << new(
              AUTOMATION_REPORTS_ID,
              AUTOMATION_REPORTS,
              enabled_by_setting: "discourse_automation_enabled",
              toggleable: false,
              features: DiscourseAi::Configuration::Feature.ai_automation_report_scripts,
              extra_check: -> { has_scripts?(["llm_report"]) },
            )
            base_modules << new(
              AUTOMATION_TRIAGE_ID,
              AUTOMATION_TRIAGE,
              enabled_by_setting: "discourse_automation_enabled",
              toggleable: false,
              features: DiscourseAi::Configuration::Feature.ai_automation_triage_scripts,
              extra_check: -> { has_scripts?(%w[llm_triage llm_agent_triage]) },
            )
          end

          # external modules from plugin registry
          DiscoursePluginRegistry
            .external_ai_features
            .group_by { |e| e[:module_name] }
            .each do |mod_name, entries|
              module_id = external_module_id(mod_name)
              features =
                entries.map do |e|
                  setting_name = "#{mod_name}_#{e[:feature]}_agent"
                  DiscourseAi::Configuration::Feature.new(
                    e[:feature].to_s,
                    setting_name,
                    module_id,
                    mod_name.to_s,
                    enabled_by_setting: e[:enabled_by_setting],
                    metadata_lookup: -> { e[:entry_point] ? { entry_point: e[:entry_point] } : {} },
                  )
                end
              base_modules << new(
                module_id,
                mod_name,
                features:,
                extra_check: -> { features.any?(&:enabled?) },
                visible: entries.any? { |e| e.fetch(:visible, true) },
              )
            end

          base_modules
        end

        def has_scripts?(script_names)
          DB
            .query_single(
              "SELECT COUNT(*) FROM discourse_automation_automations WHERE script IN (:names) and enabled",
              names: script_names,
            )
            .first
            .to_i > 0
        end

        def find_by(id:)
          all.find { |m| m.id == id }
        end
      end

      def initialize(
        id,
        name,
        enabled_by_setting: nil,
        features: [],
        extra_check: nil,
        visible: true,
        toggleable: true,
        setup_check: nil,
        status_lookup: nil,
        model_names_lookup: nil
      )
        @id = id
        @name = name
        @enabled_by_setting = enabled_by_setting
        @features = features
        @extra_check = extra_check
        @visible = visible
        @toggleable = toggleable
        @setup_check = setup_check
        @status_lookup = status_lookup
        @model_names_lookup = model_names_lookup
      end

      attr_reader :id, :name, :enabled_by_setting, :features

      def visible?
        @visible
      end

      # Whether the module's own prerequisites for being enabled are in place.
      def setup_complete?
        @setup_check.nil? || @setup_check.call
      end

      # A summary that replaces the generic on/off status in the admin features list.
      def status
        @status_lookup&.call
      end

      # The models shown for the module, when they are not the LLMs its features use.
      def model_names
        @model_names_lookup&.call
      end

      def toggle_setting
        enabled_by_setting.presence if @toggleable
      end

      def enabled?
        return @extra_check.present? ? @extra_check.call : true if enabled_by_setting.blank?

        enabled_setting = SiteSetting.get(enabled_by_setting)

        if @extra_check
          enabled_setting && @extra_check.call
        else
          enabled_setting
        end
      end
    end
  end
end
