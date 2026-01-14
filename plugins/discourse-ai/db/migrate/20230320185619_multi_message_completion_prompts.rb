# frozen_string_literal: true

class MultiMessageCompletionPrompts < ActiveRecord::Migration[7.0]
  def change
    add_column :completion_prompts, :messages, :jsonb
  end
end
