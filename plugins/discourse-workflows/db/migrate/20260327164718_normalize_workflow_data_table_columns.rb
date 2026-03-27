# frozen_string_literal: true

class NormalizeWorkflowDataTableColumns < ActiveRecord::Migration[8.0]
  def up
    create_table :discourse_workflows_data_table_columns do |t|
      t.bigint :data_table_id, null: false
      t.string :name, null: false, limit: 63
      t.string :column_type, null: false, limit: 20
      t.integer :position, null: false
      t.timestamps null: false
    end

    add_index :discourse_workflows_data_table_columns, :data_table_id
    add_index :discourse_workflows_data_table_columns, %i[data_table_id name], unique: true
    add_index :discourse_workflows_data_table_columns, %i[data_table_id position], unique: true
  end

  def down
    drop_table :discourse_workflows_data_table_columns
  end
end
