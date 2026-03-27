# frozen_string_literal: true

class DropLegacyWorkflowDataTableSchema < ActiveRecord::Migration[8.0]
  def up
    remove_column :discourse_workflows_data_tables, :columns
    drop_table :discourse_workflows_data_table_rows
  end

  def down
    add_column :discourse_workflows_data_tables, :columns, :jsonb, default: [], null: false

    create_table :discourse_workflows_data_table_rows do |t|
      t.integer :data_table_id, null: false
      t.jsonb :data, null: false, default: {}
      t.timestamps null: false
    end

    add_index :discourse_workflows_data_table_rows, :data_table_id
  end
end
