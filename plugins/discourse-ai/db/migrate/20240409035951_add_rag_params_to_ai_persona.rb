# frozen_string_literal: true

class AddRagParamsToAiPersona < ActiveRecord::Migration[7.0]
  def change
    # the default fits without any data loss in a 384 token vector representation
    # larger embedding models can easily fit larger chunks so this is configurable
    add_column :ai_personas, :rag_chunk_tokens, :integer, null: false, default: 374
    add_column :ai_personas, :rag_chunk_overlap_tokens, :integer, null: false, default: 10
    add_column :ai_personas, :rag_conversation_chunks, :integer, null: false, default: 10
  end
end
