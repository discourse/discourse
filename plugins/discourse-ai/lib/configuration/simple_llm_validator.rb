# frozen_string_literal: true

module DiscourseAi
  module Configuration
    class SimpleLlmValidator
      def initialize(opts = {})
        @opts = opts
      end

      def valid_value?(val)
        return true if val == ""

        run_test(val).tap { |result| @unreachable = result }
      rescue StandardError => e
        raise e if Rails.env.test?
        @unreachable = true
        true
      end

      def run_test(val)
        if Rails.env.test?
          # In test mode, we assume the model is reachable.
          return true
        end

        DiscourseAi::Completions::Llm
          .proxy(val)
          .generate("How much is 1 + 1?", user: nil, feature_name: "llm_validator")
          .present?
      end

      def error_message
        return unless @unreachable

        I18n.t("discourse_ai.llm.configuration.model_unreachable")
      end
    end
  end
end
