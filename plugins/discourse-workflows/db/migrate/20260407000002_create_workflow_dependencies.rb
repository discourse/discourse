# frozen_string_literal: true

class CreateWorkflowDependencies < ActiveRecord::Migration[7.2]
  def change
    create_table :discourse_workflows_workflow_dependencies do |t|
      t.integer :workflow_id, null: false
      t.string :dependency_type, null: false, limit: 50
      t.string :dependency_key, null: false, limit: 500
      t.string :node_id, limit: 100
      t.datetime :created_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
    end

    add_index :discourse_workflows_workflow_dependencies, :workflow_id
    add_index :discourse_workflows_workflow_dependencies,
              %i[dependency_type dependency_key],
              name: "idx_workflow_deps_type_key"
    add_foreign_key :discourse_workflows_workflow_dependencies,
                    :discourse_workflows_workflows,
                    column: :workflow_id,
                    on_delete: :cascade
  end
end
