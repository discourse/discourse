# frozen_string_literal: true

module DiscourseAi
  module Summarization
    class << self
      def topic_summary(topic, locale: nil, llm_model: nil)
        return nil if !SiteSetting.ai_summarization_enabled
        if (ai_agent = AiAgent.find_by_id_from_cache(SiteSetting.ai_summarization_agent)).blank?
          return nil
        end

        locale ||= source_locale(topic)

        llm_model ||= find_summarization_model(ai_agent)
        return nil if llm_model.blank?

        DiscourseAi::Summarization::FoldContent.new(
          DiscourseAi::Summarization::Strategies::TopicSummary.new(topic, locale:),
        ) { build_bot(ai_agent.class_instance, llm_model) }
      end

      def topic_gist(topic, locale: nil, llm_model: nil)
        return nil if !SiteSetting.ai_summarization_enabled
        if (ai_agent = AiAgent.find_by_id_from_cache(SiteSetting.ai_summary_gists_agent)).blank?
          return nil
        end

        llm_model ||= find_summarization_model(ai_agent)
        return nil if llm_model.blank?

        locale ||= gist_source_locale(topic)
        strategy = DiscourseAi::Summarization::Strategies::HotTopicGists.new(topic, locale:)

        DiscourseAi::Summarization::FoldContent.new(strategy) do
          build_bot(ai_agent.class_instance, llm_model, output_tool: strategy.output_tool)
        end
      end

      def chat_channel_summary(channel, time_window_in_hours, llm_model: nil)
        return nil if !SiteSetting.ai_summarization_enabled
        if (ai_agent = AiAgent.find_by_id_from_cache(SiteSetting.ai_summarization_agent)).blank?
          return nil
        end

        llm_model ||= find_summarization_model(ai_agent)
        return nil if llm_model.blank?

        DiscourseAi::Summarization::FoldContent.new(
          DiscourseAi::Summarization::Strategies::ChatMessages.new(channel, time_window_in_hours),
          persist_summaries: false,
        ) { build_bot(ai_agent.class_instance, llm_model) }
      end

      def gist_locales(topic)
        topic_source_locale = source_locale(topic)
        locales =
          if SiteSetting.content_localization_enabled
            [*SiteSetting.content_localization_locales, topic_source_locale]
          else
            [topic_source_locale]
          end

        locales.each_with_object([]) do |locale, result|
          normalized_locale = LocaleNormalizer.normalize_to_i18n(locale)&.to_s
          next if normalized_locale.blank?
          next if result.any? { |existing| LocaleNormalizer.is_same?(existing, normalized_locale) }

          result << normalized_locale
        end
      end

      def source_locale(topic)
        LocaleNormalizer.normalize_to_i18n(raw_source_locale(topic))&.to_s
      end

      def display_locale(topic, scope:)
        source_locale = raw_source_locale(topic)

        locale =
          if ContentLocalization.show_translated_topic?(topic, scope)
            SiteSetting.content_localization_locales.find do |supported_locale|
              LocaleNormalizer.is_same?(supported_locale, I18n.locale)
            end || source_locale
          else
            source_locale
          end

        LocaleNormalizer.normalize_to_i18n(locale)&.to_s
      end

      def gist_source_locale(topic)
        normalized_source_locale = source_locale(topic)
        return if normalized_source_locale.blank?

        gist_locales(topic).find do |locale|
          LocaleNormalizer.is_same?(locale, normalized_source_locale)
        end || normalized_source_locale
      end

      def gist_for(topic, scope:)
        locale = display_locale(topic, scope:)
        return if locale.blank?

        topic.ai_gist_summaries.to_a.find do |summary|
          summary.locale.present? && LocaleNormalizer.is_same?(summary.locale, locale)
        end
      end

      # Priorities are:
      #   1. Agent's default LLM
      #   2. SiteSetting.ai_default_llm_model (or newest LLM if not set)
      # @param agent [AiAgent, Class] - an agent record or its class instance; only default_llm_id is read
      def find_summarization_model(agent)
        model_id = agent.default_llm_id || SiteSetting.ai_default_llm_model

        if model_id.present?
          LlmModel.find_by(id: model_id)
        else
          LlmModel.last
        end
      end

      ### Private

      def build_bot(agent_klass, llm_model, output_tool: nil)
        agent = agent_klass.new

        if output_tool
          agent.define_singleton_method(:available_tools) { [output_tool] }
          agent.define_singleton_method(:force_tool_use) { [output_tool] }
          agent.define_singleton_method(:defer_forced_tool_for_vision?) { true }
          agent.define_singleton_method(:forced_tool_count) { 1 }
          agent.define_singleton_method(:response_format) { nil }
        end

        user = User.find_by(id: agent_klass.user_id) || Discourse.system_user

        DiscourseAi::Agents::Bot.as(user, agent:, model: llm_model)
      end

      private

      def raw_source_locale(topic)
        topic.locale.presence || SiteSetting.default_locale
      end
    end
  end
end
