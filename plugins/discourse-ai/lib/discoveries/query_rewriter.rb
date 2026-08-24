# frozen_string_literal: true

module DiscourseAi
  module Discoveries
    class QueryRewriter
      MAX_KEYWORD_QUERY_LENGTH = 200
      MAX_SEMANTIC_QUERY_LENGTH = 300
      RESPONSE_FORMAT = [
        { "key" => "keyword_query", "type" => "string" },
        { "key" => "semantic_query", "type" => "string" },
      ].freeze

      Result = Struct.new(:keyword_query, :semantic_query, keyword_init: true)

      def initialize(user:, ai_agent:, llm_model:, cancel_manager: nil)
        @user = user
        @ai_agent = ai_agent
        @llm_model = llm_model
        @cancel_manager = cancel_manager
      end

      def call(query)
        original_query = query.to_s
        context =
          DiscourseAi::Agents::BotContext.new(
            user: @user,
            messages: [
              {
                type: :user,
                content:
                  JSON.generate(
                    query: original_query,
                    forum_default_locale: SiteSetting.default_locale,
                  ),
              },
            ],
            skip_show_thinking: true,
            feature_name: "discover_query_rewrite",
            cancel_manager: @cancel_manager,
          )
        bot =
          DiscourseAi::Agents::Bot.as(
            Discourse.system_user,
            agent: rewrite_agent,
            model: @llm_model,
          )
        output = nil

        bot.reply(context) { |partial, _, type| output = partial if type == :structured_output }

        Result.new(
          keyword_query:
            normalized_query(
              output&.read_buffered_property(:keyword_query),
              original_query,
              MAX_KEYWORD_QUERY_LENGTH,
            ),
          semantic_query:
            normalized_query(
              output&.read_buffered_property(:semantic_query),
              original_query,
              MAX_SEMANTIC_QUERY_LENGTH,
            ),
        )
      rescue StandardError => error
        Rails.logger.warn("Discourse AI Discoveries query rewrite failed: #{error.class}")
        Result.new(keyword_query: original_query, semantic_query: original_query)
      end

      private

      def rewrite_agent
        response_format = RESPONSE_FORMAT

        Class
          .new(@ai_agent.class_instance) do
            define_method(:tools) { [] }
            define_method(:available_tools) { [] }
            define_method(:runtime_tools) { |**| [] }
            define_method(:native_tools) { [] }
            define_method(:required_tools) { [] }
            define_method(:force_tool_use) { [] }
            define_method(:forced_tool_count) { -1 }
            define_method(:response_format) { response_format }
          end
          .new
      end

      def normalized_query(value, fallback, max_length)
        normalized = value.to_s.dup.force_encoding(Encoding::UTF_8).scrub.unicode_normalize(:nfc)
        normalized.squish.first(max_length).presence || fallback
      end
    end
  end
end
