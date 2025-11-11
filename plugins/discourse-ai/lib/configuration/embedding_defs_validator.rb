# frozen_string_literal: true

module DiscourseAi
  module Configuration
    class EmbeddingDefsValidator
      def initialize(opts = {})
        @opts = opts
      end

      def valid_value?(val)
        if val.blank?
          if SiteSetting.ai_embeddings_enabled
            @disable_embeddings = true
            return false
          else
            return true
          end
        end

        return true if Rails.env.test? && @opts[:run_check_in_tests].blank?

        embedding_def = EmbeddingDefinition.find_by(id: val)
        if embedding_def.present?
          DiscourseAi::Embeddings::Vector.new(embedding_def).vector_from("this is a test")
        end

        true
      rescue Net::HTTPBadResponse => e
        false
      end

      def error_message
        if @disable_embeddings
          return I18n.t("discourse_ai.embeddings.configuration.disable_embeddings")
        end

        I18n.t("discourse_ai.embeddings.configuration.model_test_failed")
      end
    end
  end
end
