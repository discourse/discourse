# frozen_string_literal: true

class AddRequireApprovalToAiAgents < ActiveRecord::Migration[7.2]
  def change
    add_column :ai_agents, :require_approval, :boolean, default: false, null: false
  end
end
