# frozen_string_literal: true
class AddSettingSchemaToWorkflowVersions < ActiveRecord::Migration[8.0]
  def change
    add_column :discourse_workflows_workflow_versions,
               :setting_schema,
               :jsonb,
               null: false,
               default: []
  end
end
