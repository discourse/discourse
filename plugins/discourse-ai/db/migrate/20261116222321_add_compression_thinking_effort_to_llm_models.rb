# frozen_string_literal: true
class AddCompressionThinkingEffortToLlmModels < ActiveRecord::Migration[8.1]
  def change
    add_column :llm_models, :compression_thinking_effort, :string, null: true
  end
end
