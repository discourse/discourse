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

      class << self
        def all
          [
            new(
              SUMMARIZATION_ID,
              SUMMARIZATION,
              enabled_by_setting: "ai_summarization_enabled",
              features: DiscourseAi::Configuration::Feature.summarization_features,
            ),
            new(
              SEARCH_ID,
              SEARCH,
              enabled_by_setting: "ai_bot_enabled",
              features: DiscourseAi::Configuration::Feature.search_features,
              extra_check: -> { SiteSetting.ai_bot_discover_persona.present? },
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
        end

        def find_by(id:)
          all.find { |m| m.id == id }
        end
      end

      def initialize(id, name, enabled_by_setting: nil, features: [], extra_check: nil)
        @id = id
        @name = name
        @enabled_by_setting = enabled_by_setting
        @features = features
        @extra_check = extra_check
      end

      attr_reader :id, :name, :enabled_by_setting, :features

      def enabled?
        return @extra_check.call if enabled_by_setting.blank? && @extra_check.present?

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
