# frozen_string_literal: true

module DiscourseAi
  module Configuration
    class EmbeddingsDependencyValidator
      def initialize(opts = {})
        @opts = opts
      end

      def valid_value?(val)
        return true if val == false || val == "f" || val == "false"

        DiscourseAi::Embeddings.enabled?
      end

      def error_message
        I18n.t("discourse_ai.embeddings.configuration.enable_embeddings_first")
      end
    end
  end
end
