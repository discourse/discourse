# frozen_string_literal: true

class AiEmbeddingDefinitionSerializer < ApplicationSerializer
  root "ai_embedding"

  attributes :id,
             :display_name,
             :dimensions,
             :max_sequence_length,
             :pg_function,
             :provider,
             :url,
             :api_key,
             :seeded,
             :tokenizer_class,
             :embed_prompt,
             :search_prompt,
             :matryoshka_dimensions,
             :provider_params

  def api_key
    object.seeded? ? "********" : object.api_key
  end

  def url
    object.seeded? ? "********" : object.url
  end

  def provider
    object.seeded? ? "CDCK" : object.provider
  end
end
