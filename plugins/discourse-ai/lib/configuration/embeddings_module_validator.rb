# frozen_string_literal: true

module DiscourseAi
  module Configuration
    class EmbeddingsModuleValidator
      def initialize(opts = {})
        @opts = opts
      end

      def valid_value?(val)
        return true if val == "f"
        return true if Rails.env.test?

        SiteSetting.ai_embeddings_selected_model.present?
      end

      def error_message
        I18n.t("discourse_ai.embeddings.configuration.choose_model")
      end
    end
  end
end
