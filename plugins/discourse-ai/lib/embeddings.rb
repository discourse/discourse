# frozen_string_literal: true

module DiscourseAi
  module Embeddings
    def self.enabled?
      SiteSetting.ai_embeddings_enabled && SiteSetting.ai_embeddings_selected_model.present? &&
        EmbeddingDefinition.exists?(id: SiteSetting.ai_embeddings_selected_model)
    end

    # @return [Hash, nil] the admin features list status, nil for the generic status
    def self.admin_status
      return { state: "setup", note_key: "no_embedding_model" } if !EmbeddingDefinition.exists?
      if !EmbeddingDefinition.exists?(id: SiteSetting.ai_embeddings_selected_model)
        { state: "setup", note_key: "no_embedding_model_selected" }
      end
    end
  end
end
