# frozen_string_literal: true

class AddToolOptionsToAiToolActions < ActiveRecord::Migration[8.0]
  def change
    add_column :ai_tool_actions, :tool_options, :jsonb, default: {}, null: false
  end
end
