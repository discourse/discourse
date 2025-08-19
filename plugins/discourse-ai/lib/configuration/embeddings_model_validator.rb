# frozen_string_literal: true

module DiscourseAi
  module Configuration
    class EmbeddingsModelValidator
      def initialize(opts = {})
        @opts = opts
      end

      def valid_value?(val)
        return true if Rails.env.test?

        representation =
          DiscourseAi::Embeddings::VectorRepresentations::Base.find_representation(val)

        return false if representation.nil?

        if !representation.correctly_configured?
          @representation = representation
          return false
        end

        if !can_generate_embeddings?(val)
          @unreachable = true
          return false
        end

        true
      end

      def error_message
        return(I18n.t("discourse_ai.embeddings.configuration.model_unreachable")) if @unreachable

        @representation&.configuration_hint
      end

      def can_generate_embeddings?(val)
        vdef = DiscourseAi::Embeddings::VectorRepresentations::Base.find_representation(val).new
        DiscourseAi::Embeddings::Vector.new(vdef).vector_from("this is a test").present?
      end
    end
  end
end
