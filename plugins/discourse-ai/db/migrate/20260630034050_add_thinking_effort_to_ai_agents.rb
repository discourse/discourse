# frozen_string_literal: true

class AddThinkingEffortToAiAgents < ActiveRecord::Migration[8.0]
  def change
    add_column :ai_agents, :thinking_effort, :string, null: true
  end
end
