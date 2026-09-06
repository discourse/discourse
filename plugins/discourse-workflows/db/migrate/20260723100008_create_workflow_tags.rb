# frozen_string_literal: true

class CreateWorkflowTags < ActiveRecord::Migration[8.0]
  def change
    create_table :discourse_workflows_tags do |t|
      t.string :name, null: false, limit: 100
      t.timestamps null: false
    end
    add_index :discourse_workflows_tags, :name, unique: true, name: "idx_dwf_tags_on_name"

    create_table :discourse_workflows_workflow_tags do |t|
      t.bigint :workflow_id, null: false
      t.bigint :workflow_tag_id, null: false
      t.datetime :created_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
    end
    add_index :discourse_workflows_workflow_tags,
              %i[workflow_id workflow_tag_id],
              unique: true,
              name: "idx_dwf_workflow_tags_on_workflow_tag"
    add_index :discourse_workflows_workflow_tags,
              %i[workflow_tag_id workflow_id],
              unique: true,
              name: "idx_dwf_workflow_tags_on_tag_workflow"
  end
end
