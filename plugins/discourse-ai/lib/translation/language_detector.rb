# frozen_string_literal: true

module DiscourseAi
  module Translation
    class LanguageDetector
      # reject non-language code responses by IETF language tag: https://datatracker.ietf.org/doc/html/rfc5646
      LANGUAGE_TAG_REGEXP = /\A[A-Za-z]{2,4}(-[A-Za-z]{4})?(-([A-Za-z]{2}|[0-9]{3}))?\z/

      DETECTION_CHAR_LIMIT = 1000

      def initialize(text, topic: nil, post: nil)
        @text = text
        @topic = topic
        @post = post
      end

      def detect
        return nil if !SiteSetting.ai_translation_enabled
        return nil if @text.blank?
        if (
             ai_persona =
               AiPersona.find_by_id_from_cache(SiteSetting.ai_translation_locale_detector_persona)
           ).blank?
          return nil
        end

        persona_klass = ai_persona.class_instance
        persona = persona_klass.new

        llm_model = DiscourseAi::Translation::BaseTranslator.preferred_llm_model(persona_klass)
        return nil if llm_model.blank?

        bot =
          DiscourseAi::Personas::Bot.as(
            ai_persona.user || Discourse.system_user,
            persona: persona,
            model: llm_model,
          )

        context =
          DiscourseAi::Personas::BotContext.new(
            user: ai_persona.user || Discourse.system_user,
            skip_tool_details: true,
            feature_name: "translation",
            messages: [{ type: :user, content: @text }],
            topic: @topic,
            post: @post,
          )

        result = +""
        bot.reply(context) do |partial|
          next if partial.strip.blank?
          result << partial
        end

        result.match?(LANGUAGE_TAG_REGEXP) ? result : nil
      end
    end
  end
end
