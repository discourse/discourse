# frozen_string_literal: true

class AddCostMetricsToLlmModel < ActiveRecord::Migration[7.2]
  def change
    add_column :llm_models, :input_cost, :float
    add_column :llm_models, :cached_input_cost, :float
    add_column :llm_models, :output_cost, :float
  end
end
