# frozen_string_literal: true

module DiscourseAi
  module Configuration
    class Module
      SUMMARIZATION = "summarization"
      SEARCH = "search"
      DISCORD = "discord"
      INFERENCE = "inference"
      AI_HELPER = "ai_helper"
      TRANSLATION = "translation"
      BOT = "bot"
      SPAM = "spam"
      EMBEDDINGS = "embeddings"
      AUTOMATION_REPORTS = "automation_reports"
      AUTOMATION_TRIAGE = "automation_triage"

      NAMES = [
        SUMMARIZATION,
        SEARCH,
        DISCORD,
        INFERENCE,
        AI_HELPER,
        TRANSLATION,
        BOT,
        SPAM,
        EMBEDDINGS,
        AUTOMATION_REPORTS,
        AUTOMATION_TRIAGE,
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

      class << self
        def registered_modules
          @registered_modules ||= {}
        end

        def register(
          key,
          module_id:,
          module_name:,
          features:,
          enabled_by_setting: nil,
          extra_check: nil,
          visible: true
        )
          existing = registered_modules[key]
          if existing
            existing[:features].concat(Array(features))
          else
            registered_modules[key] = {
              module_id: module_id,
              module_name: module_name,
              features: Array(features),
              enabled_by_setting: enabled_by_setting,
              extra_check: extra_check,
              visible:,
            }
          end
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
              enabled_by_setting: "ai_discover_enabled",
              features: DiscourseAi::Configuration::Feature.search_features,
            ),
            new(
              DISCORD_ID,
              DISCORD,
              enabled_by_setting: "ai_discord_search_enabled",
              features: DiscourseAi::Configuration::Feature.discord_features,
            ),
            new(
              INFERENCE_ID,
              INFERENCE,
              enabled_by_setting: "inferred_concepts_enabled",
              features: DiscourseAi::Configuration::Feature.inference_features,
            ),
            new(
              AI_HELPER_ID,
              AI_HELPER,
              enabled_by_setting: "ai_helper_enabled",
              features: DiscourseAi::Configuration::Feature.ai_helper_features,
            ),
            new(
              TRANSLATION_ID,
              TRANSLATION,
              enabled_by_setting: "ai_translation_enabled",
              features: DiscourseAi::Configuration::Feature.translation_features,
            ),
            new(
              BOT_ID,
              BOT,
              enabled_by_setting: "ai_bot_enabled",
              features: DiscourseAi::Configuration::Feature.bot_features,
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
              extra_check: -> { SiteSetting.ai_embeddings_semantic_search_enabled },
            ),
          ]

          if SiteSetting.discourse_automation_enabled
            base_modules << new(
              AUTOMATION_REPORTS_ID,
              AUTOMATION_REPORTS,
              enabled_by_setting: "discourse_automation_enabled",
              features: DiscourseAi::Configuration::Feature.ai_automation_report_scripts,
              extra_check: -> { has_scripts?(["llm_report"]) },
            )
            base_modules << new(
              AUTOMATION_TRIAGE_ID,
              AUTOMATION_TRIAGE,
              enabled_by_setting: "discourse_automation_enabled",
              features: DiscourseAi::Configuration::Feature.ai_automation_triage_scripts,
              extra_check: -> { has_scripts?(%w[llm_triage llm_agent_triage]) },
            )
          end

          registered_modules.each_value do |mod|
            base_modules << new(
              mod[:module_id],
              mod[:module_name],
              enabled_by_setting: mod[:enabled_by_setting],
              features: mod[:features],
              extra_check: mod[:extra_check],
              visible: mod.fetch(:visible, true),
            )
          end

          base_modules
        end

        # Private
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
        visible: true
      )
        @id = id
        @name = name
        @enabled_by_setting = enabled_by_setting
        @features = features
        @extra_check = extra_check
        @visible = visible
      end

      attr_reader :id, :name, :enabled_by_setting, :features

      def visible?
        @visible
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
