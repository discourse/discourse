# frozen_string_literal: true

class AddVisionLlmModelToLlmModels < ActiveRecord::Migration[8.0]
  def change
    add_column :llm_models, :vision_llm_model_id, :bigint
    add_index :llm_models, :vision_llm_model_id
  end
end
