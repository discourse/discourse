# frozen_string_literal: true

class AddAiSecretIdToLlmAndEmbedding < ActiveRecord::Migration[7.0]
  def change
    add_column :llm_models, :ai_secret_id, :integer, null: true
    add_column :embedding_definitions, :ai_secret_id, :integer, null: true

    add_index :llm_models, :ai_secret_id
    add_index :embedding_definitions, :ai_secret_id
  end
end
