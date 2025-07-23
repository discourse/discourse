# frozen_string_literal: true

module DiscourseAi
  module Embeddings
    def self.enabled?
      SiteSetting.ai_embeddings_enabled && SiteSetting.ai_embeddings_selected_model.present? &&
        EmbeddingDefinition.exists?(id: SiteSetting.ai_embeddings_selected_model)
    end
  end
end
