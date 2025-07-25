# frozen_string_literal: true

module DiscourseAi
  module Configuration
    class EmbeddingDefsValidator
      def initialize(opts = {})
        @opts = opts
      end

      def valid_value?(val)
        val.present? || !SiteSetting.ai_embeddings_enabled
      end

      def error_message
        I18n.t("discourse_ai.embeddings.configuration.disable_embeddings")
      end
    end
  end
end
