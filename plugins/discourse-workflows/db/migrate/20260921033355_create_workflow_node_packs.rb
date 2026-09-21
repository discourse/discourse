# frozen_string_literal: true

class CreateWorkflowNodePacks < ActiveRecord::Migration[8.0]
  def change
    create_table :discourse_workflows_node_packs do |table|
      table.string :key, null: false, limit: 32
      table.string :name, null: false, limit: 60
      table.string :version, null: false, limit: 32
      table.jsonb :manifest, null: false
      table.string :manifest_sha256, null: false, limit: 64
      table.jsonb :approved_destinations, null: false, default: []
      table.boolean :enabled, null: false, default: true
      table.boolean :palette_visible, null: false, default: true
      table.integer :installed_by_id, null: false
      table.integer :updated_by_id
      table.datetime :removed_at
      table.timestamps
    end
    add_index :discourse_workflows_node_packs, :key, unique: true

    create_table :discourse_workflows_node_pack_definitions do |table|
      table.bigint :node_pack_id, null: false
      table.string :identifier, null: false, limit: 100
      table.string :version, null: false, limit: 16
      table.jsonb :definition, null: false
      table.string :definition_sha256, null: false, limit: 64
      table.string :introduced_in, null: false, limit: 32
      table.datetime :retired_at
      table.timestamps
    end
    add_index :discourse_workflows_node_pack_definitions,
              %i[identifier version],
              unique: true,
              name: "idx_workflow_node_pack_definitions_identity"
    add_index :discourse_workflows_node_pack_definitions, :node_pack_id
  end
end
