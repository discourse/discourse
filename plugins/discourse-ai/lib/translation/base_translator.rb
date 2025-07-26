# frozen_string_literal: true

module DiscourseAi
  module Translation
    class BaseTranslator
      def initialize(text:, target_locale:, topic: nil, post: nil)
        @text = text
        @target_locale = target_locale
        @topic = topic
        @post = post
      end

      def translate
        return nil if !SiteSetting.ai_translation_enabled
        if (ai_persona = AiPersona.find_by(id: persona_setting)).blank?
          return nil
        end
        translation_user = ai_persona.user || Discourse.system_user
        persona_klass = ai_persona.class_instance
        persona = persona_klass.new

        model = self.class.preferred_llm_model(persona_klass)
        return nil if model.blank?

        bot = DiscourseAi::Personas::Bot.as(translation_user, persona:, model:)

        ContentSplitter
          .split(content: @text, chunk_size: model.max_output_tokens)
          .map { |text| get_translation(text:, bot:, translation_user:) }
          .join("")
      end

      private

      def formatted_content(content)
        { content:, target_locale: @target_locale }.to_json
      end

      def get_translation(text:, bot:, translation_user:)
        context =
          DiscourseAi::Personas::BotContext.new(
            user: translation_user,
            skip_tool_details: true,
            feature_name: "translation",
            messages: [{ type: :user, content: formatted_content(text) }],
            topic: @topic,
            post: @post,
          )
        max_tokens = get_max_tokens(text)
        llm_args = { max_tokens: }

        result = +""
        bot.reply(context, llm_args:) { |partial| result << partial }
        result
      end

      def get_max_tokens(text)
        if text.length < 100
          500
        elsif text.length < 500
          1000
        else
          text.length * 2
        end
      end

      def persona_setting
        raise NotImplementedError
      end

      def self.preferred_llm_model(persona_klass)
        model_id = persona_klass.default_llm_id || SiteSetting.ai_default_llm_model

        if model_id.present?
          LlmModel.find_by(id: model_id)
        else
          LlmModel.last
        end
      end
    end
  end
end
