# frozen_string_literal: true

module DiscourseAi
  module Configuration
    class SentimentAgentValidator
      def initialize(opts = {})
        @opts = opts
      end

      def valid_value?(val)
        @result = DiscourseAi::Sentiment::AgentConfigurationValidator.validate(:sentiment, val)

        invalid_problems.empty?
      end

      def error_message
        I18n.t(
          "discourse_ai.sentiment.configuration.invalid_agent",
          classification_type: :sentiment,
          expected_keys: @result.expected_keys.join(", "),
          actual_keys: @result.actual_keys.presence&.join(", ") || no_response_format_keys_message,
        )
      end

      private

      def invalid_problems
        @result.problems - %i[missing_llm]
      end

      def no_response_format_keys_message
        I18n.t("discourse_ai.sentiment.configuration.no_response_format_keys")
      end
    end
  end
end
