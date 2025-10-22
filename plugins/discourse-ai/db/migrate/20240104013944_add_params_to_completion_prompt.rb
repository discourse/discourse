# frozen_string_literal: true

class AddParamsToCompletionPrompt < ActiveRecord::Migration[7.0]
  def change
    add_column :completion_prompts, :temperature, :integer
    add_column :completion_prompts, :stop_sequences, :string, array: true
  end
end
