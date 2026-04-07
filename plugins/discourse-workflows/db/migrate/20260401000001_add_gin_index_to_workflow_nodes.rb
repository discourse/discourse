# frozen_string_literal: true

class AddGinIndexToWorkflowNodes < ActiveRecord::Migration[7.2]
  def change
    add_index :discourse_workflows_workflows, :nodes, using: :gin, name: "idx_workflows_nodes_gin"
  end
end
