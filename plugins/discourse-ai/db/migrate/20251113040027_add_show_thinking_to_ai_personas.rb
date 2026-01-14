# frozen_string_literal: true

class AddShowThinkingToAiPersonas < ActiveRecord::Migration[7.1]
  def change
    add_column :ai_personas, :show_thinking, :boolean, default: true, null: false

    execute <<~SQL
      UPDATE ai_personas
      SET show_thinking = tool_details
    SQL
  end
end
