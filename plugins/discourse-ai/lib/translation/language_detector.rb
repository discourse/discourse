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
             ai_agent =
               AiAgent.find_by_id_from_cache(SiteSetting.ai_translation_locale_detector_agent)
           ).blank?
          return nil
        end

        agent_klass = ai_agent.class_instance
        agent = agent_klass.new

        llm_model = DiscourseAi::Translation::BaseTranslator.preferred_llm_model(agent_klass)
        return nil if llm_model.blank?

        bot =
          DiscourseAi::Agents::Bot.as(
            ai_agent.user || Discourse.system_user,
            agent: agent,
            model: llm_model,
          )

        context =
          DiscourseAi::Agents::BotContext.new(
            user: ai_agent.user || Discourse.system_user,
            skip_show_thinking: true,
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
