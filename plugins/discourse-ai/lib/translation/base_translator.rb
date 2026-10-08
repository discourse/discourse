# frozen_string_literal: true

module DiscourseAi
  module Translation
    class BaseTranslator
      DEFAULT_OUTPUT_TOKEN_BUDGET = 2500
      TRANSLATION_EXPANSION_FACTOR = 2
      PROMPT_TOKEN_RESERVE = 256

      def initialize(
        text:,
        target_locale:,
        content_description: nil,
        topic: nil,
        post: nil,
        llm_model: nil
      )
        @text = text
        @target_locale = target_locale
        @content_description = content_description
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
        tokenizer = model.tokenizer_class
        payload_overhead = tokenizer.size(formatted_content(""))
        output_tokens = output_token_budget(bot, translation_user)
        chunk_size = output_tokens / TRANSLATION_EXPANSION_FACTOR
        chunks =
          ContentSplitter.split(content: @text, chunk_size:) do |text|
            [tokenizer.size(text), tokenizer.size(formatted_content(text)) - payload_overhead].max
          end

        translated =
          chunks
            .map { |text| get_translation(text:, bot:, translation_user:, output_tokens:) }
            .join("")

        strip_control_characters(translated)
      end

      private

      def output_token_budget(bot, translation_user)
        llm = bot.llm
        agent = bot.agent
        context = translation_context(text: "", translation_user:)
        prompt = agent.craft_prompt(context, llm:)
        response_format =
          if agent.response_format.present?
            DiscourseAi::Agents::Bot.build_json_schema(agent.response_format)
          end
        size, capacity =
          llm.prompt_capacity(
            prompt,
            max_tokens: 1,
            max_tokens_is_total: true,
            thinking_effort: agent.thinking_effort,
            response_format:,
          )
        threshold = (agent.class.compression_threshold || 80).to_i.clamp(1, 100)
        available_tokens = capacity * threshold / 100 - size - PROMPT_TOKEN_RESERVE
        work_budget =
          DiscourseAi::Completions::TurnWorkBudget.new(
            limit:
              DiscourseAi::Agents::Bot.effective_max_turn_tokens(llm, agent.class.max_turn_tokens),
          )
        output_limit =
          work_budget.generation_options(
            {},
            maximum: bot.model.max_output_tokens || DEFAULT_OUTPUT_TOKEN_BUDGET,
            tools: prompt.tools.present?,
          )[
            :max_tokens
          ]
        # Fixed examples must fit without triggering context compression.
        output_tokens = [
          output_limit,
          available_tokens * TRANSLATION_EXPANSION_FACTOR * 100 /
            (100 + threshold * TRANSLATION_EXPANSION_FACTOR),
        ].min
        if output_tokens <= 0
          raise DiscourseAi::Completions::ContextPreparation::Error.new("hard_overflow")
        end
        output_tokens
      end

      def formatted_content(content)
        payload = { content:, target_locale: @target_locale }
        payload[:content_description] = @content_description if @content_description.present?

        # JSON.generate over to_json: ActiveSupport HTML-escapes <, >, and & into
        # \uXXXX sequences, which models can mis-copy into control characters
        JSON.generate(payload)
      end

      # control characters are never valid in a translation, but models
      # occasionally emit them by mangling unicode escapes (e.g. \u003c
      # coming back as \u001c)
      def strip_control_characters(text)
        text.gsub(/[\u0000-\u0008\u000B-\u001F\u007F\u0080-\u009F]/, "")
      end

      def get_translation(text:, bot:, translation_user:, output_tokens:)
        context = translation_context(text:, translation_user:)
        llm_args = { max_tokens: output_tokens }

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

      def translation_context(text:, translation_user:)
        DiscourseAi::Agents::BotContext.new(
          user: translation_user,
          skip_show_thinking: true,
          feature_name: "translation",
          messages: [{ type: :user, content: formatted_content(text) }],
          topic: @topic,
          post: @post,
        )
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
