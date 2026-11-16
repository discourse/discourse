# frozen_string_literal: true
class AddVariablesSchemaToWorkflowVersions < ActiveRecord::Migration[8.0]
  def change
    add_column :discourse_workflows_workflow_versions,
               :variables_schema,
               :jsonb,
               null: false,
               default: []
  end
end
