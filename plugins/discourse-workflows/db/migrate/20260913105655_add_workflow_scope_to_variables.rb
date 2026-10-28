# frozen_string_literal: true
class AddWorkflowScopeToVariables < ActiveRecord::Migration[8.0]
  def change
    add_column :discourse_workflows_variables, :workflow_id, :bigint
    add_column :discourse_workflows_variables,
               :variable_type,
               :string,
               limit: 30,
               null: false,
               default: "string"
    add_column :discourse_workflows_variables, :type_options, :jsonb, null: false, default: {}
    change_column :discourse_workflows_variables, :value, :text, default: nil
    change_column_null :discourse_workflows_variables, :value, true

    remove_index :discourse_workflows_variables, :key, name: "idx_dwf_variables_on_key"
    add_index :discourse_workflows_variables,
              %i[workflow_id key],
              unique: true,
              where: "workflow_id IS NOT NULL",
              name: "idx_dwf_variables_on_workflow_key"
    add_index :discourse_workflows_variables,
              :key,
              unique: true,
              where: "workflow_id IS NULL",
              name: "idx_dwf_variables_on_key_global"
  end
end
