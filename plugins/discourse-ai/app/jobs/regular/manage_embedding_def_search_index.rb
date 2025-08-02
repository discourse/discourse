# frozen_string_literal: true

module ::Jobs
  class ManageEmbeddingDefSearchIndex < ::Jobs::Base
    def execute(args)
      embedding_def = EmbeddingDefinition.find_by(id: args[:id])
      return if embedding_def.nil?
      return if DiscourseAi::Embeddings::Schema.correctly_indexed?(embedding_def)

      DiscourseAi::Embeddings::Schema.prepare_search_indexes(embedding_def)
    end
  end
end
