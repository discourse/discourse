# frozen_string_literal: true

module DiscourseAi
  module Translation
    class LanguageDetector
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
             ai_persona = AiPersona.find_by(id: SiteSetting.ai_translation_locale_detector_persona)
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
        result
      end
    end
  end
end
