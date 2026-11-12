# frozen_string_literal: true
class AddColumnOrderToDiscourseWorkflowsDataTables < ActiveRecord::Migration[8.1]
  def change
    add_column :discourse_workflows_data_tables,
               :column_order,
               :string,
               array: true,
               null: false,
               default: []
  end
end
