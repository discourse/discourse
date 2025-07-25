# frozen_string_literal: true

class AddMaxOutputTokensToLlmModel < ActiveRecord::Migration[7.2]
  def change
    add_column :llm_models, :max_output_tokens, :integer
  end
end
