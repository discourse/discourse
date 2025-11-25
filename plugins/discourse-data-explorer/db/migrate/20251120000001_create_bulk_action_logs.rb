# frozen_string_literal: true

class CreateBulkActionLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :data_explorer_bulk_action_logs do |t|
      t.bigint :automation_id, null: true
      t.bigint :query_id, null: false
      t.datetime :executed_at, null: false
      t.integer :total_rows, null: false, default: 0
      t.integer :success_count, null: false, default: 0
      t.integer :error_count, null: false, default: 0
      t.jsonb :errors_detail, null: false, default: []
      t.string :action_type, null: false
      t.timestamps
    end

    add_index :data_explorer_bulk_action_logs, :automation_id
    add_index :data_explorer_bulk_action_logs, :query_id
    add_index :data_explorer_bulk_action_logs, :executed_at
  end
end
