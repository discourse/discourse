# frozen_string_literal: true

class AddAgenticFieldsToAiPersonas < ActiveRecord::Migration[7.2]
  def up
    add_column :ai_personas, :max_turn_tokens, :integer, null: true
    add_column :ai_personas, :compression_threshold, :integer, null: true
    add_column :ai_personas, :execution_mode, :string, default: "default", null: false
  end

  def down
    remove_column :ai_personas, :max_turn_tokens
    remove_column :ai_personas, :compression_threshold
    remove_column :ai_personas, :execution_mode
  end
end
