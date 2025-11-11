# frozen_string_literal: true

class AddForcedToolCountToAiPersonas < ActiveRecord::Migration[7.1]
  def change
    add_column :ai_personas, :forced_tool_count, :integer, default: -1, null: false
  end
end
