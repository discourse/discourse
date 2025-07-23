# frozen_string_literal: true

class DropCompletionPromptValue < ActiveRecord::Migration[7.0]
  def change
    remove_column :completion_prompts, :value, :text
  end
end
