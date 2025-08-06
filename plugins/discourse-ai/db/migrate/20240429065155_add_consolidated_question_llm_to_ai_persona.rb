# frozen_string_literal: true

class AddConsolidatedQuestionLlmToAiPersona < ActiveRecord::Migration[7.0]
  def change
    add_column :ai_personas, :question_consolidator_llm, :text, max_length: 2000
  end
end
