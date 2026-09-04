# frozen_string_literal: true

module DiscourseAi
  module Embeddings
    class << self
      def enabled?
        SiteSetting.ai_embeddings_enabled && SiteSetting.ai_embeddings_selected_model.present? &&
          EmbeddingDefinition.exists?(id: SiteSetting.ai_embeddings_selected_model)
      end
    end
  end
end
