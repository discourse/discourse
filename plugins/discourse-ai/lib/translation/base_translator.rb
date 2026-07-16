# frozen_string_literal: true

module DiscourseAi
  module Translation
    class BaseTranslator
      def initialize(text:, target_locale:, topic: nil, post: nil, llm_model: nil)
        @text = text
        @target_locale = target_locale
        @topic = topic
        @post = post
        @llm_model = llm_model
      end

      def translate
        return nil if @text.blank?
        return nil if !SiteSetting.ai_translation_enabled
        if (ai_agent = AiAgent.find_by_id_from_cache(agent_setting)).blank?
          return nil
        end
        translation_user = ai_agent.user || Discourse.system_user
        agent_klass = ai_agent.class_instance
        agent = agent_klass.new

        model = @llm_model || self.class.preferred_llm_model(agent_klass)
        return nil if model.blank?

        bot = DiscourseAi::Agents::Bot.as(translation_user, agent:, model:)

        translated =
          ContentSplitter
            .split(content: @text, chunk_size: model.max_output_tokens)
            .map { |text| get_translation(text:, bot:, translation_user:, model:) }
            .join("")

        strip_control_characters(translated)
      end

      private

      def formatted_content(content)
        # JSON.generate over to_json: ActiveSupport HTML-escapes <, >, and & into
        # \uXXXX sequences, which models can mis-copy into control characters
        JSON.generate({ content:, target_locale: @target_locale })
      end

      # control characters are never valid in a translation, but models
      # occasionally emit them by mangling unicode escapes (e.g. \u003c
      # coming back as \u001c)
      def strip_control_characters(text)
        text.gsub(/[\u0000-\u0008\u000B-\u001F\u007F\u0080-\u009F]/, "")
      end

      def get_translation(text:, bot:, translation_user:, model:)
        context =
          DiscourseAi::Agents::BotContext.new(
            user: translation_user,
            skip_show_thinking: true,
            feature_name: "translation",
            messages: [{ type: :user, content: formatted_content(text) }],
            topic: @topic,
            post: @post,
          )
        llm_args = { max_tokens: model.max_output_tokens }

        structured_output = nil
        result = +""
        bot.reply(context, llm_args:) do |partial, _, type|
          if type == :structured_output
            structured_output = partial
          else
            result << partial
          end
        end
        structured_output&.read_buffered_property(:output) || result
      end

      def agent_setting
        raise NotImplementedError
      end

      def self.preferred_llm_model(agent_klass)
        model_id = agent_klass.default_llm_id || SiteSetting.ai_default_llm_model

        if model_id.present?
          LlmModel.find_by(id: model_id)
        else
          LlmModel.last
        end
      end
    end
  end
end
