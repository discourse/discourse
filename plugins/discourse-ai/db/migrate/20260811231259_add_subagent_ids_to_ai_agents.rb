# frozen_string_literal: true

class AddSubagentIdsToAiAgents < ActiveRecord::Migration[8.0]
  def change
    add_column :ai_agents, :subagent_ids, :bigint, array: true, null: false, default: []
  end
end
