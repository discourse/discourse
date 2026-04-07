# frozen_string_literal: true

class DropUnusedDataTableRows < ActiveRecord::Migration[7.2]
  def up
    drop_table :discourse_workflows_data_table_rows, if_exists: true
  end

  def down
    create_table :discourse_workflows_data_table_rows do |t|
      t.integer :data_table_id, null: false
      t.jsonb :data, null: false, default: {}
      t.timestamps null: false
    end

    add_index :discourse_workflows_data_table_rows, :data_table_id
  end
end
