# frozen_string_literal: true

module DiscourseAi
  module Summarization
    class << self
      def topic_summary(topic)
        return nil if !SiteSetting.ai_summarization_enabled
        if (ai_persona = AiPersona.find_by(id: SiteSetting.ai_summarization_persona)).blank?
          return nil
        end

        persona_klass = ai_persona.class_instance
        llm_model = find_summarization_model(persona_klass)
        return nil if llm_model.blank?

        DiscourseAi::Summarization::FoldContent.new(
          build_bot(persona_klass, llm_model),
          DiscourseAi::Summarization::Strategies::TopicSummary.new(topic),
        )
      end

      def topic_gist(topic)
        return nil if !SiteSetting.ai_summarization_enabled
        if (ai_persona = AiPersona.find_by(id: SiteSetting.ai_summary_gists_persona)).blank?
          return nil
        end

        persona_klass = ai_persona.class_instance
        llm_model = find_summarization_model(persona_klass)
        return nil if llm_model.blank?

        DiscourseAi::Summarization::FoldContent.new(
          build_bot(persona_klass, llm_model),
          DiscourseAi::Summarization::Strategies::HotTopicGists.new(topic),
        )
      end

      def chat_channel_summary(channel, time_window_in_hours)
        return nil if !SiteSetting.ai_summarization_enabled
        if (ai_persona = AiPersona.find_by(id: SiteSetting.ai_summarization_persona)).blank?
          return nil
        end

        persona_klass = ai_persona.class_instance
        llm_model = find_summarization_model(persona_klass)
        return nil if llm_model.blank?

        DiscourseAi::Summarization::FoldContent.new(
          build_bot(persona_klass, llm_model),
          DiscourseAi::Summarization::Strategies::ChatMessages.new(channel, time_window_in_hours),
          persist_summaries: false,
        )
      end

      # Priorities are:
      #   1. Persona's default LLM
      #   2. Hidden `ai_summarization_model` setting
      #   3. Newest LLM config
      def find_summarization_model(persona_klass)
        model_id =
          persona_klass.default_llm_id || SiteSetting.ai_summarization_model&.split(":")&.last # Remove legacy custom provider.

        if model_id.present?
          LlmModel.find_by(id: model_id)
        else
          LlmModel.last
        end
      end

      ### Private

      def build_bot(persona_klass, llm_model)
        persona = persona_klass.new
        user = User.find_by(id: persona_klass.user_id) || Discourse.system_user

        bot = DiscourseAi::Personas::Bot.as(user, persona: persona, model: llm_model)
      end
    end
  end
end
