# frozen_string_literal: true
class AddRagLlmModel < ActiveRecord::Migration[7.2]
  def change
    add_column :ai_personas, :rag_llm_model_id, :bigint
    add_column :ai_tools, :rag_llm_model_id, :bigint
  end
end
