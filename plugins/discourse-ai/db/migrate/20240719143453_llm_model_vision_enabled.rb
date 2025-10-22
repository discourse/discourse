# frozen_string_literal: true
class LlmModelVisionEnabled < ActiveRecord::Migration[7.1]
  def change
    add_column :llm_models, :vision_enabled, :boolean, default: false, null: false
  end
end
